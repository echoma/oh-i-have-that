package main

import (
	"context"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tencentyun/cos-go-sdk-v5"
	"github.com/tencentyun/scf-go-lib/cloudfunction"
)

// APIGatewayRequest API网关请求结构
type APIGatewayRequest struct {
	HTTPMethod      string            `json:"httpMethod"`
	Path            string            `json:"path"`
	QueryString     map[string]string `json:"queryString"`
	Headers         map[string]string `json:"headers"`
	Body            string            `json:"body"`
	PathParameters  map[string]string `json:"pathParameters"`
	StageVariables  map[string]string `json:"stageVariables"`
	RequestContext  RequestContext    `json:"requestContext"`
	IsBase64Encoded bool              `json:"isBase64Encoded"`
}

// RequestContext 请求上下文
type RequestContext struct {
	ServiceId  string   `json:"serviceId"`
	Path       string   `json:"path"`
	HTTPMethod string   `json:"httpMethod"`
	RequestId  string   `json:"requestId"`
	Identity   Identity `json:"identity"`
	SourceIp   string   `json:"sourceIp"`
	Stage      string   `json:"stage"`
}

// Identity 身份信息
type Identity struct {
	SecretId string `json:"secretId"`
}

// APIGatewayResponse API网关响应结构
type APIGatewayResponse struct {
	IsBase64Encoded bool              `json:"isBase64Encoded"`
	StatusCode      int               `json:"statusCode"`
	Headers         map[string]string `json:"headers"`
	Body            string            `json:"body"`
}

// User 用户结构
type User struct {
	ID       string `json:"id"`
	Email    string `json:"email"`
	Password string `json:"password"` // 实际应用中应该是加密后的密码
	Username string `json:"username"`
	Status   string `json:"status"`
}

// UserDatabase 用户数据库结构（存储在COS中）
type UserDatabase struct {
	Users     map[string]User `json:"users"`
	UpdatedAt time.Time       `json:"updatedAt"`
}

// LoginRequest 登录请求
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// LoginResponse 登录响应
type LoginResponse struct {
	Success  bool   `json:"success"`
	Message  string `json:"message"`
	Token    string `json:"token,omitempty"`
	Username string `json:"username,omitempty"`
	UserID   string `json:"userId,omitempty"`
}

// AuthCheckRequest 身份验证检查请求
type AuthCheckRequest struct {
	Token string `json:"token" binding:"required"`
}

// AuthCheckResponse 身份验证检查响应
type AuthCheckResponse struct {
	Valid    bool   `json:"valid"`
	Username string `json:"username,omitempty"`
	UserID   string `json:"userId,omitempty"`
}

// COS客户端
var cosClient *cos.Client

// 初始化用户数据（存储在COS中的默认数据）
var defaultUsers = UserDatabase{
	Users: map[string]User{
		"user001": {
			ID:       "user001",
			Email:    "admin@example.com",
			Password: "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8", // "password" 的SHA256
			Username: "管理员",
			Status:   "active",
		},
		"user002": {
			ID:       "user002",
			Email:    "zhangsan@example.com",
			Password: "ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f", // "secret123" 的SHA256
			Username: "张三",
			Status:   "active",
		},
		"user003": {
			ID:       "user003",
			Email:    "lisi@example.com",
			Password: "2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b", // "hello456" 的SHA256
			Username: "李四",
			Status:   "active",
		},
	},
	UpdatedAt: time.Now(),
}

// 初始化COS客户端
func initCOSClient() {
	// 从环境变量获取COS配置
	secretID := os.Getenv("COS_SECRET_ID")
	secretKey := os.Getenv("COS_SECRET_KEY")
	region := os.Getenv("COS_REGION")
	bucketName := os.Getenv("COS_BUCKET_NAME")

	if secretID == "" || secretKey == "" || region == "" || bucketName == "" {
		log.Println("警告: COS配置不完整，使用模拟数据")
		return
	}

	bucketURL := fmt.Sprintf("https://%s.cos.%s.myqcloud.com", bucketName, region)
	serviceURL := fmt.Sprintf("https://cos.%s.myqcloud.com", region)

	b, _ := cos.NewBaseURL(bucketURL)
	s, _ := cos.NewBaseURL(serviceURL)

	cosClient = cos.NewClient(&cos.BaseURL{
		BucketURL:  b,
		ServiceURL: s,
	}, &http.Client{
		Transport: &cos.AuthorizationTransport{
			SecretID:  secretID,
			SecretKey: secretKey,
		},
	})
}

// 从COS加载用户数据
func loadUsersFromCOS() (*UserDatabase, error) {
	if cosClient == nil {
		// 如果COS客户端未初始化，返回默认数据
		return &defaultUsers, nil
	}

	resp, err := cosClient.Object.Get(context.Background(), "data/users.json", nil)
	if err != nil {
		// 如果文件不存在，创建默认数据
		log.Printf("用户数据文件不存在，创建默认数据: %v", err)
		err = saveUsersToCOS(&defaultUsers)
		if err != nil {
			log.Printf("保存默认用户数据失败: %v", err)
		}
		return &defaultUsers, nil
	}
	defer resp.Body.Close()

	var userDB UserDatabase
	err = json.NewDecoder(resp.Body).Decode(&userDB)
	if err != nil {
		log.Printf("解析用户数据失败: %v", err)
		return &defaultUsers, nil
	}

	return &userDB, nil
}

// 保存用户数据到COS
func saveUsersToCOS(userDB *UserDatabase) error {
	if cosClient == nil {
		return fmt.Errorf("COS客户端未初始化")
	}

	userDB.UpdatedAt = time.Now()
	data, err := json.MarshalIndent(userDB, "", "  ")
	if err != nil {
		return err
	}

	_, err = cosClient.Object.Put(context.Background(), "data/users.json", strings.NewReader(string(data)), nil)
	return err
}

// 生成简单的token（实际应用中应使用JWT）
func generateToken(userID string) string {
	timestamp := time.Now().Unix()
	data := fmt.Sprintf("%s:%d", userID, timestamp)
	hash := md5.Sum([]byte(data))
	return fmt.Sprintf("%x", hash)
}

// 验证token（简单实现，实际应用中应使用JWT验证）
func validateToken(token string, userDB *UserDatabase) (string, bool) {
	// 这里是简化的token验证逻辑
	// 实际应用中应该使用JWT或其他安全的token机制
	for userID := range userDB.Users {
		expectedToken := generateToken(userID)
		if token == expectedToken {
			return userID, true
		}
	}
	return "", false
}

// 设置Gin路由
func setupRouter() *gin.Engine {
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(corsMiddleware())

	// 身份验证API
	api := r.Group("/api/v1/auth")
	{
		api.GET("/health", healthCheck)
		api.POST("/login", login)
		api.POST("/check", checkAuth)
		api.POST("/logout", logout)
	}

	// 根路径
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Auth Service API",
			"version": "1.0.0",
			"service": "auth-service",
			"time":    time.Now().Format(time.RFC3339),
		})
	})

	return r
}

// CORS中间件
func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization")
		c.Header("Access-Control-Allow-Credentials", "true")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// 健康检查
func healthCheck(c *gin.Context) {
	c.JSON(200, gin.H{
		"status":  "healthy",
		"service": "auth-service",
		"time":    time.Now().Format(time.RFC3339),
	})
}

// 用户登录
func login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, LoginResponse{
			Success: false,
			Message: "请求参数错误",
		})
		return
	}

	// 加载用户数据
	userDB, err := loadUsersFromCOS()
	if err != nil {
		c.JSON(500, LoginResponse{
			Success: false,
			Message: "系统错误",
		})
		return
	}

	// 查找用户
	var foundUser *User
	for _, user := range userDB.Users {
		if user.Email == req.Email {
			foundUser = &user
			break
		}
	}

	if foundUser == nil {
		c.JSON(401, LoginResponse{
			Success: false,
			Message: "邮箱或密码错误",
		})
		return
	}

	// 验证密码（这里应该使用安全的密码验证）
	// 简化实现：直接比较（实际应用中应该比较哈希值）
	if foundUser.Password != req.Password {
		c.JSON(401, LoginResponse{
			Success: false,
			Message: "邮箱或密码错误",
		})
		return
	}

	// 检查用户状态
	if foundUser.Status != "active" {
		c.JSON(401, LoginResponse{
			Success: false,
			Message: "账户已被禁用",
		})
		return
	}

	// 生成token
	token := generateToken(foundUser.ID)

	// 设置Cookie
	c.SetCookie("auth_token", token, 3600*24*7, "/", "", false, true) // 7天有效期

	c.JSON(200, LoginResponse{
		Success:  true,
		Message:  "登录成功",
		Token:    token,
		Username: foundUser.Username,
		UserID:   foundUser.ID,
	})
}

// 检查身份验证状态
func checkAuth(c *gin.Context) {
	// 从Cookie或请求体获取token
	token := c.GetHeader("Authorization")
	if token == "" {
		token, _ = c.Cookie("auth_token")
	}
	if token == "" {
		var req AuthCheckRequest
		if err := c.ShouldBindJSON(&req); err == nil {
			token = req.Token
		}
	}

	if token == "" {
		c.JSON(401, AuthCheckResponse{
			Valid: false,
		})
		return
	}

	// 加载用户数据
	userDB, err := loadUsersFromCOS()
	if err != nil {
		c.JSON(500, AuthCheckResponse{
			Valid: false,
		})
		return
	}

	// 验证token
	userID, valid := validateToken(token, userDB)
	if !valid {
		c.JSON(401, AuthCheckResponse{
			Valid: false,
		})
		return
	}

	user, exists := userDB.Users[userID]
	if !exists || user.Status != "active" {
		c.JSON(401, AuthCheckResponse{
			Valid: false,
		})
		return
	}

	c.JSON(200, AuthCheckResponse{
		Valid:    true,
		Username: user.Username,
		UserID:   user.ID,
	})
}

// 用户登出
func logout(c *gin.Context) {
	// 清除Cookie
	c.SetCookie("auth_token", "", -1, "/", "", false, true)

	c.JSON(200, gin.H{
		"success": true,
		"message": "登出成功",
	})
}

// SCF处理函数
func handler(ctx context.Context, event APIGatewayRequest) (APIGatewayResponse, error) {
	gin.SetMode(gin.TestMode)

	router := setupRouter()

	req, err := http.NewRequest(event.HTTPMethod, event.Path, strings.NewReader(event.Body))
	if err != nil {
		return APIGatewayResponse{
			StatusCode: 500,
			Body:       `{"error": "创建请求失败"}`,
			Headers: map[string]string{
				"Content-Type": "application/json",
			},
		}, nil
	}

	// 设置查询参数
	q := req.URL.Query()
	for k, v := range event.QueryString {
		q.Add(k, v)
	}
	req.URL.RawQuery = q.Encode()

	// 设置请求头
	for k, v := range event.Headers {
		req.Header.Set(k, v)
	}

	// 创建响应记录器
	w := &responseWriter{
		headers: make(map[string]string),
	}

	router.ServeHTTP(w, req)

	return APIGatewayResponse{
		StatusCode:      w.statusCode,
		Headers:         w.headers,
		Body:            w.body,
		IsBase64Encoded: false,
	}, nil
}

// 自定义响应写入器
type responseWriter struct {
	statusCode int
	headers    map[string]string
	body       string
}

func (w *responseWriter) Header() http.Header {
	h := make(http.Header)
	for k, v := range w.headers {
		h.Set(k, v)
	}
	return h
}

func (w *responseWriter) Write(data []byte) (int, error) {
	w.body = string(data)
	return len(data), nil
}

func (w *responseWriter) WriteHeader(statusCode int) {
	w.statusCode = statusCode
}

func main() {
	// 初始化COS客户端
	initCOSClient()

	if os.Getenv("SCF_RUNTIME_API") != "" {
		cloudfunction.Start(handler)
	} else {
		router := setupRouter()
		port := os.Getenv("PORT")
		if port == "" {
			port = "9001"
		}

		log.Printf("Auth Service服务器启动在端口 %s", port)
		log.Fatal(http.ListenAndServe(":"+port, router))
	}
}

package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
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
	ID        string    `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	Phone     string    `json:"phone"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// 模拟用户数据库
var users = map[string]User{
	"user1": {
		ID:        "user1",
		Username:  "张三",
		Email:     "zhangsan@example.com",
		Phone:     "13800138001",
		Status:    "active",
		CreatedAt: time.Now().Add(-time.Hour * 24 * 30),
		UpdatedAt: time.Now().Add(-time.Hour * 2),
	},
	"user2": {
		ID:        "user2",
		Username:  "李四",
		Email:     "lisi@example.com",
		Phone:     "13800138002",
		Status:    "active",
		CreatedAt: time.Now().Add(-time.Hour * 24 * 15),
		UpdatedAt: time.Now().Add(-time.Minute * 30),
	},
	"user3": {
		ID:        "user3",
		Username:  "王五",
		Email:     "wangwu@example.com",
		Phone:     "13800138003",
		Status:    "inactive",
		CreatedAt: time.Now().Add(-time.Hour * 24 * 7),
		UpdatedAt: time.Now().Add(-time.Hour * 1),
	},
}

// 设置Gin路由
func setupRouter() *gin.Engine {
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(corsMiddleware())

	// 用户管理API
	api := r.Group("/api/v1/users")
	{
		api.GET("/health", healthCheck)
		api.GET("/", listUsers)
		api.GET("/:id", getUser)
		api.POST("/", createUser)
		api.PUT("/:id", updateUser)
		api.DELETE("/:id", deleteUser)
		api.POST("/:id/activate", activateUser)
		api.POST("/:id/deactivate", deactivateUser)
	}

	// 根路径
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "User Service API",
			"version": "1.0.0",
			"service": "user-service",
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
		"service": "user-service",
		"time":    time.Now().Format(time.RFC3339),
	})
}

// 获取用户列表
func listUsers(c *gin.Context) {
	status := c.Query("status")
	var result []User

	for _, user := range users {
		if status == "" || user.Status == status {
			result = append(result, user)
		}
	}

	c.JSON(200, gin.H{
		"users": result,
		"total": len(result),
	})
}

// 获取单个用户
func getUser(c *gin.Context) {
	userID := c.Param("id")

	user, exists := users[userID]
	if !exists {
		c.JSON(404, gin.H{
			"error": "用户不存在",
			"code":  "USER_NOT_FOUND",
		})
		return
	}

	c.JSON(200, gin.H{
		"user": user,
	})
}

// 创建用户
func createUser(c *gin.Context) {
	var req struct {
		Username string `json:"username" binding:"required"`
		Email    string `json:"email" binding:"required,email"`
		Phone    string `json:"phone"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{
			"error": "请求参数错误",
			"code":  "INVALID_REQUEST",
			"details": err.Error(),
		})
		return
	}

	// 生成新用户ID
	userID := fmt.Sprintf("user%d", len(users)+1)

	// 检查邮箱是否已存在
	for _, user := range users {
		if user.Email == req.Email {
			c.JSON(409, gin.H{
				"error": "邮箱已存在",
				"code":  "EMAIL_EXISTS",
			})
			return
		}
	}

	newUser := User{
		ID:        userID,
		Username:  req.Username,
		Email:     req.Email,
		Phone:     req.Phone,
		Status:    "active",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	users[userID] = newUser

	c.JSON(201, gin.H{
		"user": newUser,
	})
}

// 更新用户
func updateUser(c *gin.Context) {
	userID := c.Param("id")

	user, exists := users[userID]
	if !exists {
		c.JSON(404, gin.H{
			"error": "用户不存在",
			"code":  "USER_NOT_FOUND",
		})
		return
	}

	var req struct {
		Username string `json:"username"`
		Email    string `json:"email"`
		Phone    string `json:"phone"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{
			"error": "请求参数错误",
			"code":  "INVALID_REQUEST",
		})
		return
	}

	// 更新字段
	if req.Username != "" {
		user.Username = req.Username
	}
	if req.Email != "" {
		user.Email = req.Email
	}
	if req.Phone != "" {
		user.Phone = req.Phone
	}
	user.UpdatedAt = time.Now()

	users[userID] = user

	c.JSON(200, gin.H{
		"user": user,
	})
}

// 删除用户
func deleteUser(c *gin.Context) {
	userID := c.Param("id")

	_, exists := users[userID]
	if !exists {
		c.JSON(404, gin.H{
			"error": "用户不存在",
			"code":  "USER_NOT_FOUND",
		})
		return
	}

	delete(users, userID)

	c.JSON(200, gin.H{
		"message": "用户删除成功",
	})
}

// 激活用户
func activateUser(c *gin.Context) {
	userID := c.Param("id")

	user, exists := users[userID]
	if !exists {
		c.JSON(404, gin.H{
			"error": "用户不存在",
			"code":  "USER_NOT_FOUND",
		})
		return
	}

	user.Status = "active"
	user.UpdatedAt = time.Now()
	users[userID] = user

	c.JSON(200, gin.H{
		"user": user,
	})
}

// 停用用户
func deactivateUser(c *gin.Context) {
	userID := c.Param("id")

	user, exists := users[userID]
	if !exists {
		c.JSON(404, gin.H{
			"error": "用户不存在",
			"code":  "USER_NOT_FOUND",
		})
		return
	}

	user.Status = "inactive"
	user.UpdatedAt = time.Now()
	users[userID] = user

	c.JSON(200, gin.H{
		"user": user,
	})
}

// SCF处理函数
func handler(ctx context.Context, event APIGatewayRequest) (APIGatewayResponse, error) {
	gin.SetMode(gin.TestMode)

	router := setupRouter()

	req, err := http.NewRequest(event.HTTPMethod, event.Path, nil)
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
	if os.Getenv("SCF_RUNTIME_API") != "" {
		cloudfunction.Start(handler)
	} else {
		router := setupRouter()
		port := os.Getenv("PORT")
		if port == "" {
			port = "9001"
		}

		log.Printf("User Service服务器启动在端口 %s", port)
		log.Fatal(http.ListenAndServe(":"+port, router))
	}
}
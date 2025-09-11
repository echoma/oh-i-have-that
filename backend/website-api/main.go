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

// UserInfo 用户信息结构
type UserInfo struct {
	ID       string    `json:"id"`
	Username string    `json:"username"`
	Email    string    `json:"email"`
	LoginAt  time.Time `json:"loginAt"`
}

// 模拟用户数据库
var users = map[string]UserInfo{
	"user1": {
		ID:       "user1",
		Username: "张三",
		Email:    "zhangsan@example.com",
		LoginAt:  time.Now().Add(-time.Hour * 2),
	},
	"user2": {
		ID:       "user2",
		Username: "李四",
		Email:    "lisi@example.com",
		LoginAt:  time.Now().Add(-time.Minute * 30),
	},
}

// 设置Gin路由
func setupRouter() *gin.Engine {
	// 设置为发布模式
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()

	// 添加中间件
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(corsMiddleware())

	// API路由组
	api := r.Group("/api/v1")
	{
		api.GET("/health", healthCheck)
		api.GET("/user/:id", getUserInfo)
		api.POST("/auth/check", checkAuth)
		api.GET("/stats", getStats)
	}

	// 根路径
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Oh I Have That API",
			"version": "1.0.0",
			"service": "website-api",
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
		"service": "website-api",
		"time":    time.Now().Format(time.RFC3339),
	})
}

// 获取用户信息
func getUserInfo(c *gin.Context) {
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

// 检查用户身份
func checkAuth(c *gin.Context) {
	var req struct {
		Token  string `json:"token"`
		UserID string `json:"userId"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{
			"error": "请求参数错误",
			"code":  "INVALID_REQUEST",
		})
		return
	}

	// 简单的token验证逻辑
	if req.Token == "" {
		c.JSON(401, gin.H{
			"error": "缺少认证token",
			"code":  "MISSING_TOKEN",
		})
		return
	}

	// 验证用户是否存在
	user, exists := users[req.UserID]
	if !exists {
		c.JSON(401, gin.H{
			"error": "用户不存在",
			"code":  "USER_NOT_FOUND",
		})
		return
	}

	// 简单的token验证（实际项目中应该使用JWT等）
	expectedToken := fmt.Sprintf("token_%s", req.UserID)
	if req.Token != expectedToken {
		c.JSON(401, gin.H{
			"error": "token无效",
			"code":  "INVALID_TOKEN",
		})
		return
	}

	c.JSON(200, gin.H{
		"valid": true,
		"user":  user,
	})
}

// 获取统计信息
func getStats(c *gin.Context) {
	c.JSON(200, gin.H{
		"totalUsers":   len(users),
		"onlineUsers":  2, // 模拟在线用户数
		"serverTime":   time.Now().Format(time.RFC3339),
		"serverRegion": os.Getenv("TENCENTCLOUD_REGION"),
		"functionName": os.Getenv("SCF_FUNCTIONNAME"),
		"service":      "website-api",
	})
}

// SCF处理函数
func handler(ctx context.Context, event APIGatewayRequest) (APIGatewayResponse, error) {
	// 设置Gin为测试模式以避免输出日志
	gin.SetMode(gin.TestMode)

	// 创建路由
	router := setupRouter()

	// 创建HTTP请求
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

	// 处理请求
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
	// 检查是否在SCF环境中运行
	if os.Getenv("SCF_RUNTIME_API") != "" {
		// SCF环境
		cloudfunction.Start(handler)
	} else {
		// 本地开发环境
		router := setupRouter()
		port := os.Getenv("PORT")
		if port == "" {
			port = "9000"
		}

		log.Printf("Website API服务器启动在端口 %s", port)
		log.Fatal(http.ListenAndServe(":"+port, router))
	}
}

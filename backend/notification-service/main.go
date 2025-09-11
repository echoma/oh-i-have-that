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

// Notification 通知结构
type Notification struct {
	ID        string     `json:"id"`
	Type      string     `json:"type"`      // email, sms, push
	Recipient string     `json:"recipient"` // 接收者
	Subject   string     `json:"subject"`
	Content   string     `json:"content"`
	Status    string     `json:"status"` // pending, sent, failed
	CreatedAt time.Time  `json:"createdAt"`
	SentAt    *time.Time `json:"sentAt,omitempty"`
}

// 模拟通知存储
var notifications = make(map[string]Notification)
var notificationCounter = 0

// 设置Gin路由
func setupRouter() *gin.Engine {
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(corsMiddleware())

	// 通知API
	api := r.Group("/api/v1/notifications")
	{
		api.GET("/health", healthCheck)
		api.POST("/send", sendNotification)
		api.GET("/", listNotifications)
		api.GET("/:id", getNotification)
		api.POST("/:id/retry", retryNotification)
	}

	// 根路径
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Notification Service API",
			"version": "1.0.0",
			"service": "notification-service",
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
		"service": "notification-service",
		"time":    time.Now().Format(time.RFC3339),
	})
}

// 发送通知
func sendNotification(c *gin.Context) {
	var req struct {
		Type      string `json:"type" binding:"required"`      // email, sms, push
		Recipient string `json:"recipient" binding:"required"` // 接收者
		Subject   string `json:"subject"`
		Content   string `json:"content" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{
			"error":   "请求参数错误",
			"code":    "INVALID_REQUEST",
			"details": err.Error(),
		})
		return
	}

	// 验证通知类型
	if req.Type != "email" && req.Type != "sms" && req.Type != "push" {
		c.JSON(400, gin.H{
			"error": "不支持的通知类型",
			"code":  "INVALID_TYPE",
		})
		return
	}

	notificationCounter++
	notificationID := fmt.Sprintf("notif_%d", notificationCounter)

	notification := Notification{
		ID:        notificationID,
		Type:      req.Type,
		Recipient: req.Recipient,
		Subject:   req.Subject,
		Content:   req.Content,
		Status:    "pending",
		CreatedAt: time.Now(),
	}

	// 模拟发送过程
	success := simulateSend(notification.Type)
	if success {
		notification.Status = "sent"
		now := time.Now()
		notification.SentAt = &now
	} else {
		notification.Status = "failed"
	}

	notifications[notificationID] = notification

	c.JSON(201, gin.H{
		"notification": notification,
	})
}

// 获取通知列表
func listNotifications(c *gin.Context) {
	status := c.Query("status")
	notifType := c.Query("type")

	var result []Notification
	for _, notification := range notifications {
		if (status == "" || notification.Status == status) &&
			(notifType == "" || notification.Type == notifType) {
			result = append(result, notification)
		}
	}

	c.JSON(200, gin.H{
		"notifications": result,
		"total":         len(result),
	})
}

// 获取单个通知
func getNotification(c *gin.Context) {
	notificationID := c.Param("id")

	notification, exists := notifications[notificationID]
	if !exists {
		c.JSON(404, gin.H{
			"error": "通知不存在",
			"code":  "NOTIFICATION_NOT_FOUND",
		})
		return
	}

	c.JSON(200, gin.H{
		"notification": notification,
	})
}

// 重试发送通知
func retryNotification(c *gin.Context) {
	notificationID := c.Param("id")

	notification, exists := notifications[notificationID]
	if !exists {
		c.JSON(404, gin.H{
			"error": "通知不存在",
			"code":  "NOTIFICATION_NOT_FOUND",
		})
		return
	}

	if notification.Status == "sent" {
		c.JSON(400, gin.H{
			"error": "通知已发送成功，无需重试",
			"code":  "ALREADY_SENT",
		})
		return
	}

	// 重新尝试发送
	success := simulateSend(notification.Type)
	if success {
		notification.Status = "sent"
		now := time.Now()
		notification.SentAt = &now
	} else {
		notification.Status = "failed"
	}

	notifications[notificationID] = notification

	c.JSON(200, gin.H{
		"notification": notification,
	})
}

// 模拟发送过程
func simulateSend(notificationType string) bool {
	// 模拟不同类型的成功率
	switch notificationType {
	case "email":
		return time.Now().Unix()%10 < 9 // 90% 成功率
	case "sms":
		return time.Now().Unix()%10 < 8 // 80% 成功率
	case "push":
		return time.Now().Unix()%10 < 7 // 70% 成功率
	default:
		return false
	}
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
			port = "9002"
		}

		log.Printf("Notification Service服务器启动在端口 %s", port)
		log.Fatal(http.ListenAndServe(":"+port, router))
	}
}

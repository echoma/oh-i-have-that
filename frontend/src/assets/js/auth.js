// 身份验证管理类
class AuthManager {
    constructor() {
        this.apiBaseUrl = this.getApiBaseUrl();
        this.currentUser = null;
        this.isAuthenticated = false;
    }

    getApiBaseUrl() {
        // 在生产环境中，这应该是您的API网关URL
        // 开发环境可能需要不同的URL
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            return 'http://localhost:9001'; // 本地开发环境
        }
        return window.location.origin; // 生产环境
    }

    // 检查用户是否已登录
    async checkAuthStatus() {
        try {
            const token = this.getToken();
            if (!token) {
                return false;
            }

            const response = await fetch(`${this.apiBaseUrl}/api/v1/auth/check`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                credentials: 'include',
                body: JSON.stringify({ token })
            });

            if (response.ok) {
                const data = await response.json();
                if (data.valid) {
                    this.currentUser = {
                        id: data.userId,
                        username: data.username
                    };
                    this.isAuthenticated = true;
                    return true;
                }
            }

            // Token无效，清除本地存储
            this.clearAuth();
            return false;
        } catch (error) {
            console.error('检查认证状态失败:', error);
            this.clearAuth();
            return false;
        }
    }

    // 用户登录
    async login(email, password) {
        try {
            const response = await fetch(`${this.apiBaseUrl}/api/v1/auth/login`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                credentials: 'include',
                body: JSON.stringify({ email, password })
            });

            const data = await response.json();

            if (response.ok && data.success) {
                // 保存认证信息
                this.setToken(data.token);
                this.currentUser = {
                    id: data.userId,
                    username: data.username
                };
                this.isAuthenticated = true;

                return {
                    success: true,
                    message: data.message,
                    user: this.currentUser
                };
            } else {
                return {
                    success: false,
                    message: data.message || '登录失败'
                };
            }
        } catch (error) {
            console.error('登录请求失败:', error);
            return {
                success: false,
                message: '网络错误，请稍后重试'
            };
        }
    }

    // 用户登出
    async logout() {
        try {
            const token = this.getToken();
            if (token) {
                await fetch(`${this.apiBaseUrl}/api/v1/auth/logout`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${token}`
                    },
                    credentials: 'include'
                });
            }
        } catch (error) {
            console.error('登出请求失败:', error);
        } finally {
            this.clearAuth();
            this.redirectToLogin();
        }
    }

    // 获取存储的token
    getToken() {
        return localStorage.getItem('auth_token') || this.getCookie('auth_token');
    }

    // 保存token
    setToken(token) {
        localStorage.setItem('auth_token', token);
        // 同时设置cookie作为备份
        this.setCookie('auth_token', token, 7); // 7天有效期
    }

    // 清除认证信息
    clearAuth() {
        localStorage.removeItem('auth_token');
        this.deleteCookie('auth_token');
        this.currentUser = null;
        this.isAuthenticated = false;
    }

    // Cookie操作辅助方法
    getCookie(name) {
        const value = `; ${document.cookie}`;
        const parts = value.split(`; ${name}=`);
        if (parts.length === 2) return parts.pop().split(';').shift();
        return null;
    }

    setCookie(name, value, days) {
        const expires = new Date();
        expires.setTime(expires.getTime() + (days * 24 * 60 * 60 * 1000));
        document.cookie = `${name}=${value};expires=${expires.toUTCString()};path=/`;
    }

    deleteCookie(name) {
        document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
    }

    // 重定向到登录页面
    redirectToLogin() {
        const currentPath = window.location.pathname;
        if (currentPath !== '/login.html' && !currentPath.endsWith('/login.html')) {
            window.location.href = '/login.html';
        }
    }

    // 重定向到主页
    redirectToHome() {
        window.location.href = '/index.html';
    }

    // 获取当前用户信息
    getCurrentUser() {
        return this.currentUser;
    }

    // 检查是否已认证
    isUserAuthenticated() {
        return this.isAuthenticated;
    }

    // 显示用户信息在页面上
    displayUserInfo(containerId = 'userInfo') {
        const container = document.getElementById(containerId);
        if (!container) return;

        if (this.isAuthenticated && this.currentUser) {
            container.innerHTML = `
                <div class="user-info">
                    <span class="welcome-text">欢迎，${this.currentUser.username}</span>
                    <button class="logout-btn" onclick="authManager.logout()">登出</button>
                </div>
            `;
            container.style.display = 'block';
        } else {
            container.style.display = 'none';
        }
    }

    // 页面加载时的认证检查
    async initPageAuth() {
        const isLoginPage = window.location.pathname.endsWith('/login.html');
        
        if (isLoginPage) {
            // 如果在登录页面，检查是否已登录
            const isAuth = await this.checkAuthStatus();
            if (isAuth) {
                this.redirectToHome();
            }
        } else {
            // 如果不在登录页面，检查是否需要登录
            const isAuth = await this.checkAuthStatus();
            if (!isAuth) {
                this.redirectToLogin();
            } else {
                // 显示用户信息
                this.displayUserInfo();
            }
        }
    }

    // 为需要认证的API请求添加token
    async authenticatedFetch(url, options = {}) {
        const token = this.getToken();
        if (!token) {
            throw new Error('未登录');
        }

        const authOptions = {
            ...options,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`,
                ...options.headers
            },
            credentials: 'include'
        };

        const response = await fetch(url, authOptions);
        
        if (response.status === 401) {
            // Token过期或无效
            this.clearAuth();
            this.redirectToLogin();
            throw new Error('认证已过期，请重新登录');
        }

        return response;
    }
}

// 创建全局认证管理器实例
const authManager = new AuthManager();

// 页面加载完成后初始化认证检查
document.addEventListener('DOMContentLoaded', () => {
    authManager.initPageAuth();
});

// 导出供其他模块使用
if (typeof module !== 'undefined' && module.exports) {
    module.exports = AuthManager;
}
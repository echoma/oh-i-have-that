// 主JavaScript文件
class SCFWebsite {
    constructor() {
        this.apiBaseUrl = this.getApiBaseUrl();
        this.init();
    }

    init() {
        console.log('Oh I Have That initialized');
        this.setupEventListeners();
        this.displayWelcomeMessage();
    }

    getApiBaseUrl() {
        // 在生产环境中，这应该是您的API网关URL
        // 这里使用相对路径，实际部署时需要替换为真实的API网关地址
        return window.location.origin;
    }

    setupEventListeners() {
        // 添加页面加载完成后的动画
        document.addEventListener('DOMContentLoaded', () => {
            this.animateElements();
        });

        // 添加滚动效果
        window.addEventListener('scroll', () => {
            this.handleScroll();
        });
    }

    displayWelcomeMessage() {
        console.log(`
🚀 欢迎使用 Oh I Have That!
📦 静态资源: COS对象存储
⚡ 动态API: SCF云函数
🔧 基础设施: Terraform
        `);
    }

    animateElements() {
        const cards = document.querySelectorAll('.feature-card');
        cards.forEach((card, index) => {
            setTimeout(() => {
                card.style.opacity = '0';
                card.style.transform = 'translateY(20px)';
                card.style.transition = 'all 0.6s ease-out';
                
                setTimeout(() => {
                    card.style.opacity = '1';
                    card.style.transform = 'translateY(0)';
                }, 100);
            }, index * 200);
        });
    }

    handleScroll() {
        const scrolled = window.pageYOffset;
        const parallax = document.querySelector('.header');
        if (parallax) {
            const speed = scrolled * 0.5;
            parallax.style.transform = `translateY(${speed}px)`;
        }
    }

    async makeApiRequest(endpoint, options = {}) {
        const resultDiv = document.getElementById('api-result');
        
        try {
            resultDiv.textContent = '请求中...';
            
            const response = await fetch(`${this.apiBaseUrl}${endpoint}`, {
                method: options.method || 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    ...options.headers
                },
                body: options.body ? JSON.stringify(options.body) : undefined
            });

            const data = await response.json();
            
            resultDiv.textContent = JSON.stringify(data, null, 2);
            resultDiv.style.color = response.ok ? '#2ecc71' : '#e74c3c';
            
            return data;
        } catch (error) {
            console.error('API请求失败:', error);
            resultDiv.textContent = `请求失败: ${error.message}`;
            resultDiv.style.color = '#e74c3c';
            throw error;
        }
    }

    // API测试方法
    async testHealthCheck() {
        return this.makeApiRequest('/api/v1/health');
    }

    async testUserInfo() {
        return this.makeApiRequest('/api/v1/user/user1');
    }

    async testAuth() {
        return this.makeApiRequest('/api/v1/auth/check', {
            method: 'POST',
            body: {
                token: 'token_user1',
                userId: 'user1'
            }
        });
    }

    async testStats() {
        return this.makeApiRequest('/api/v1/stats');
    }

    // 工具方法
    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.textContent = message;
        
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 1rem 1.5rem;
            border-radius: 8px;
            color: white;
            font-weight: 500;
            z-index: 1000;
            animation: slideInRight 0.3s ease-out;
            max-width: 300px;
        `;

        const colors = {
            info: '#3498db',
            success: '#2ecc71',
            warning: '#f39c12',
            error: '#e74c3c'
        };

        notification.style.backgroundColor = colors[type] || colors.info;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.style.animation = 'slideOutRight 0.3s ease-out';
            setTimeout(() => {
                document.body.removeChild(notification);
            }, 300);
        }, 3000);
    }

    // 复制到剪贴板
    async copyToClipboard(text) {
        try {
            await navigator.clipboard.writeText(text);
            this.showNotification('已复制到剪贴板', 'success');
        } catch (error) {
            console.error('复制失败:', error);
            this.showNotification('复制失败', 'error');
        }
    }

    // 格式化时间
    formatTime(date) {
        return new Intl.DateTimeFormat('zh-CN', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        }).format(new Date(date));
    }
}

// 全局函数，供HTML调用
let website;

document.addEventListener('DOMContentLoaded', () => {
    website = new SCFWebsite();
});

// 全局API测试函数
async function testHealthCheck() {
    if (website) {
        await website.testHealthCheck();
    }
}

async function testUserInfo() {
    if (website) {
        await website.testUserInfo();
    }
}

async function testAuth() {
    if (website) {
        await website.testAuth();
    }
}

async function testStats() {
    if (website) {
        await website.testStats();
    }
}

// 添加CSS动画
const style = document.createElement('style');
style.textContent = `
    @keyframes slideInRight {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOutRight {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);
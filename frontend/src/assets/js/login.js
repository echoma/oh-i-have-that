// 登录页面逻辑
class LoginPage {
    constructor() {
        this.form = document.getElementById('loginForm');
        this.emailInput = document.getElementById('email');
        this.passwordInput = document.getElementById('password');
        this.loginBtn = document.getElementById('loginBtn');
        this.btnText = this.loginBtn.querySelector('.btn-text');
        this.btnLoading = this.loginBtn.querySelector('.btn-loading');
        this.errorMessage = document.getElementById('errorMessage');
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.setupFormValidation();
        
        // 检查URL参数中是否有错误信息
        this.checkUrlParams();
        
        // 自动聚焦到邮箱输入框
        this.emailInput.focus();
    }

    setupEventListeners() {
        // 表单提交事件
        this.form.addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleLogin();
        });

        // 输入框事件
        this.emailInput.addEventListener('input', () => {
            this.clearFieldError(this.emailInput);
            this.hideError();
        });

        this.passwordInput.addEventListener('input', () => {
            this.clearFieldError(this.passwordInput);
            this.hideError();
        });

        // 回车键快捷登录
        this.passwordInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.handleLogin();
            }
        });

        // 演示账户快速填充
        this.setupDemoAccountClicks();
    }

    setupFormValidation() {
        // 实时验证
        this.emailInput.addEventListener('blur', () => {
            this.validateEmail();
        });

        this.passwordInput.addEventListener('blur', () => {
            this.validatePassword();
        });
    }

    setupDemoAccountClicks() {
        // 为演示账户添加点击事件
        const demoAccounts = document.querySelector('.demo-accounts');
        if (demoAccounts) {
            demoAccounts.addEventListener('click', (e) => {
                const text = e.target.textContent;
                
                // 检查点击的是否是演示账户信息
                if (text.includes('admin@example.com')) {
                    this.fillDemoAccount('admin@example.com', 'password');
                } else if (text.includes('zhangsan@example.com')) {
                    this.fillDemoAccount('zhangsan@example.com', 'secret123');
                } else if (text.includes('lisi@example.com')) {
                    this.fillDemoAccount('lisi@example.com', 'hello456');
                }
            });
        }
    }

    fillDemoAccount(email, password) {
        this.emailInput.value = email;
        this.passwordInput.value = password;
        this.clearAllErrors();
        this.showNotification('已填充演示账户信息', 'info');
    }

    checkUrlParams() {
        const urlParams = new URLSearchParams(window.location.search);
        const error = urlParams.get('error');
        const message = urlParams.get('message');
        
        if (error) {
            this.showError(decodeURIComponent(message || '登录失败'));
        }
    }

    validateEmail() {
        const email = this.emailInput.value.trim();
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        
        if (!email) {
            this.setFieldError(this.emailInput, '请输入邮箱地址');
            return false;
        }
        
        if (!emailRegex.test(email)) {
            this.setFieldError(this.emailInput, '请输入有效的邮箱地址');
            return false;
        }
        
        this.setFieldSuccess(this.emailInput);
        return true;
    }

    validatePassword() {
        const password = this.passwordInput.value;
        
        if (!password) {
            this.setFieldError(this.passwordInput, '请输入密码');
            return false;
        }
        
        if (password.length < 6) {
            this.setFieldError(this.passwordInput, '密码至少需要6个字符');
            return false;
        }
        
        this.setFieldSuccess(this.passwordInput);
        return true;
    }

    setFieldError(input, message) {
        const formGroup = input.closest('.form-group');
        formGroup.classList.remove('success');
        formGroup.classList.add('error');
        
        // 移除之前的错误信息
        const existingError = formGroup.querySelector('.field-error');
        if (existingError) {
            existingError.remove();
        }
        
        // 添加新的错误信息
        const errorDiv = document.createElement('div');
        errorDiv.className = 'field-error';
        errorDiv.textContent = message;
        errorDiv.style.cssText = `
            color: #e53e3e;
            font-size: 0.8rem;
            margin-top: 0.25rem;
        `;
        formGroup.appendChild(errorDiv);
    }

    setFieldSuccess(input) {
        const formGroup = input.closest('.form-group');
        formGroup.classList.remove('error');
        formGroup.classList.add('success');
        
        // 移除错误信息
        const existingError = formGroup.querySelector('.field-error');
        if (existingError) {
            existingError.remove();
        }
    }

    clearFieldError(input) {
        const formGroup = input.closest('.form-group');
        formGroup.classList.remove('error', 'success');
        
        const existingError = formGroup.querySelector('.field-error');
        if (existingError) {
            existingError.remove();
        }
    }

    clearAllErrors() {
        this.clearFieldError(this.emailInput);
        this.clearFieldError(this.passwordInput);
        this.hideError();
    }

    async handleLogin() {
        // 验证表单
        const isEmailValid = this.validateEmail();
        const isPasswordValid = this.validatePassword();
        
        if (!isEmailValid || !isPasswordValid) {
            this.showError('请检查输入信息');
            return;
        }

        // 显示加载状态
        this.setLoading(true);
        this.hideError();

        try {
            const email = this.emailInput.value.trim();
            const password = this.passwordInput.value;

            // 调用认证管理器进行登录
            const result = await authManager.login(email, password);

            if (result.success) {
                this.showSuccess('登录成功，正在跳转...');
                
                // 延迟跳转，让用户看到成功信息
                setTimeout(() => {
                    authManager.redirectToHome();
                }, 1000);
            } else {
                this.showError(result.message);
                this.setLoading(false);
            }
        } catch (error) {
            console.error('登录过程中发生错误:', error);
            this.showError('登录失败，请稍后重试');
            this.setLoading(false);
        }
    }

    setLoading(loading) {
        this.loginBtn.disabled = loading;
        
        if (loading) {
            this.btnText.style.display = 'none';
            this.btnLoading.style.display = 'flex';
        } else {
            this.btnText.style.display = 'block';
            this.btnLoading.style.display = 'none';
        }
    }

    showError(message) {
        this.errorMessage.textContent = message;
        this.errorMessage.className = 'error-message';
        this.errorMessage.style.display = 'block';
        
        // 添加震动效果
        this.errorMessage.style.animation = 'none';
        setTimeout(() => {
            this.errorMessage.style.animation = 'shake 0.5s ease-in-out';
        }, 10);
    }

    showSuccess(message) {
        this.errorMessage.textContent = message;
        this.errorMessage.className = 'success-message';
        this.errorMessage.style.display = 'block';
    }

    hideError() {
        this.errorMessage.style.display = 'none';
    }

    showNotification(message, type = 'info') {
        // 创建通知元素
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
        
        // 自动移除通知
        setTimeout(() => {
            notification.style.animation = 'slideOutRight 0.3s ease-out';
            setTimeout(() => {
                if (document.body.contains(notification)) {
                    document.body.removeChild(notification);
                }
            }, 300);
        }, 3000);
    }
}

// 页面加载完成后初始化登录页面
document.addEventListener('DOMContentLoaded', () => {
    new LoginPage();
});

// 添加必要的CSS动画
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
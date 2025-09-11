#!/usr/bin/env node

/**
 * 静态网站构建脚本
 * 将src目录的内容处理后输出到dist目录
 */

const fs = require('fs');
const path = require('path');

class StaticSiteBuilder {
    constructor() {
        this.srcDir = path.join(__dirname, 'src');
        this.distDir = path.join(__dirname, 'dist');
        this.config = this.loadConfig();
    }

    loadConfig() {
        const configPath = path.join(__dirname, 'build.config.json');
        if (fs.existsSync(configPath)) {
            return JSON.parse(fs.readFileSync(configPath, 'utf8'));
        }
        
        // 默认配置
        return {
            minify: process.env.NODE_ENV === 'production',
            apiBaseUrl: process.env.API_BASE_URL || '',
            version: process.env.VERSION || '1.0.0',
            buildTime: new Date().toISOString()
        };
    }

    async build() {
        console.log('🚀 开始构建静态网站...');
        
        // 清理dist目录
        this.cleanDist();
        
        // 创建dist目录
        this.ensureDir(this.distDir);
        
        // 复制并处理文件
        await this.processDirectory(this.srcDir, this.distDir);
        
        // 生成构建信息
        this.generateBuildInfo();
        
        console.log('✅ 构建完成!');
        console.log(`📁 输出目录: ${this.distDir}`);
    }

    cleanDist() {
        if (fs.existsSync(this.distDir)) {
            fs.rmSync(this.distDir, { recursive: true, force: true });
        }
    }

    ensureDir(dir) {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
    }

    async processDirectory(srcDir, distDir) {
        const items = fs.readdirSync(srcDir);
        
        for (const item of items) {
            const srcPath = path.join(srcDir, item);
            const distPath = path.join(distDir, item);
            const stat = fs.statSync(srcPath);
            
            if (stat.isDirectory()) {
                this.ensureDir(distPath);
                await this.processDirectory(srcPath, distPath);
            } else {
                await this.processFile(srcPath, distPath);
            }
        }
    }

    async processFile(srcPath, distPath) {
        const ext = path.extname(srcPath).toLowerCase();
        
        switch (ext) {
            case '.html':
                this.processHtml(srcPath, distPath);
                break;
            case '.css':
                this.processCss(srcPath, distPath);
                break;
            case '.js':
                this.processJs(srcPath, distPath);
                break;
            default:
                // 直接复制其他文件
                fs.copyFileSync(srcPath, distPath);
                break;
        }
        
        console.log(`📄 处理文件: ${path.relative(this.srcDir, srcPath)}`);
    }

    processHtml(srcPath, distPath) {
        let content = fs.readFileSync(srcPath, 'utf8');
        
        // 替换变量
        content = content.replace(/\{\{API_BASE_URL\}\}/g, this.config.apiBaseUrl);
        content = content.replace(/\{\{VERSION\}\}/g, this.config.version);
        content = content.replace(/\{\{BUILD_TIME\}\}/g, this.config.buildTime);
        
        // 如果是生产环境，可以进行HTML压缩
        if (this.config.minify) {
            content = this.minifyHtml(content);
        }
        
        fs.writeFileSync(distPath, content);
    }

    processCss(srcPath, distPath) {
        let content = fs.readFileSync(srcPath, 'utf8');
        
        // 如果是生产环境，可以进行CSS压缩
        if (this.config.minify) {
            content = this.minifyCss(content);
        }
        
        fs.writeFileSync(distPath, content);
    }

    processJs(srcPath, distPath) {
        let content = fs.readFileSync(srcPath, 'utf8');
        
        // 替换API基础URL
        if (this.config.apiBaseUrl) {
            content = content.replace(
                /getApiBaseUrl\(\)\s*{[^}]*}/,
                `getApiBaseUrl() { return '${this.config.apiBaseUrl}'; }`
            );
        }
        
        // 如果是生产环境，可以进行JS压缩
        if (this.config.minify) {
            content = this.minifyJs(content);
        }
        
        fs.writeFileSync(distPath, content);
    }

    minifyHtml(html) {
        // 简单的HTML压缩
        return html
            .replace(/\s+/g, ' ')
            .replace(/>\s+</g, '><')
            .trim();
    }

    minifyCss(css) {
        // 简单的CSS压缩
        return css
            .replace(/\s+/g, ' ')
            .replace(/;\s*}/g, '}')
            .replace(/{\s+/g, '{')
            .replace(/;\s+/g, ';')
            .trim();
    }

    minifyJs(js) {
        // 简单的JS压缩（移除注释和多余空格）
        return js
            .replace(/\/\*[\s\S]*?\*\//g, '')
            .replace(/\/\/.*$/gm, '')
            .replace(/\s+/g, ' ')
            .trim();
    }

    generateBuildInfo() {
        const buildInfo = {
            version: this.config.version,
            buildTime: this.config.buildTime,
            environment: process.env.NODE_ENV || 'development',
            apiBaseUrl: this.config.apiBaseUrl
        };
        
        fs.writeFileSync(
            path.join(this.distDir, 'build-info.json'),
            JSON.stringify(buildInfo, null, 2)
        );
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    const builder = new StaticSiteBuilder();
    builder.build().catch(console.error);
}

module.exports = StaticSiteBuilder;
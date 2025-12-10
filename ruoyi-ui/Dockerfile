# 第一步：打包Vue项目
FROM node:18-alpine as build-stage
WORKDIR /app
COPY package*.json ./
# 用淘宝源装依赖，速度更快
RUN npm install --registry=https://registry.npmmirror.com
COPY . .
# 打包项目（生成dist文件夹）
RUN npm run build

# 第二步：用Nginx运行打包后的文件
FROM nginx:alpine as production-stage
# 把打包好的文件复制到Nginx里
COPY --from=build-stage /app/dist /usr/share/nginx/html
# 解决Vue刷新404的配置（下一步会建这个文件）
COPY nginx.conf /etc/nginx/conf.d/default.conf
# 暴露80端口
EXPOSE 80
# 启动Nginx
CMD ["nginx", "-g", "daemon off;"]

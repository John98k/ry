# 阶段1：打包后端（替换不存在的镜像标签）
FROM maven:3.8.8-openjdk-8 AS build
WORKDIR /app
COPY . .
# 进入ruoyi-admin打包
RUN cd ruoyi-admin && mvn clean package -DskipTests

# 阶段2：运行后端（保持不变）
FROM openjdk:8-jre-alpine
WORKDIR /app
# 复制ruoyi-admin/target下的jar包（和Jenkins打包路径一致）
COPY --from=build /app/ruoyi-admin/target/ruoyi-admin.jar app.jar
# 暴露端口
EXPOSE 8080
# 启动命令
CMD ["java", "-jar", "app.jar"]
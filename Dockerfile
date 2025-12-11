# 阶段1：打包后端
FROM maven:3.9-openjdk-8 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# 阶段2：运行后端
FROM openjdk:8-jre-alpine
WORKDIR /app
# 复制打包后的jar包（RuoYi-Vue后端默认打包到ruoyi-admin/target/）
COPY --from=build /app/ruoyi-admin/target/ruoyi-admin.jar app.jar
# 暴露端口
EXPOSE 8080
# 启动命令
CMD ["java", "-jar", "app.jar"]
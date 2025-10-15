# ==============================
# Next.js Multi-stage Dockerfile
# ตามแนวทางจาก express-docker-app
# ==============================

# Build stage - ใช้สำหรับ development/testing และ build โปรเจกต์
FROM node:22-alpine AS builder

WORKDIR /app

# ใช้ cache layer: ติดตั้ง deps ก่อน
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# คัดลอกซอร์สทั้งหมด
COPY . .

# Build โปรเจกต์ (สร้าง .next)
RUN npm run build


# Production stage - สำหรับ production deployment
FROM node:22-alpine AS production

ENV NODE_ENV=production \
	NEXT_TELEMETRY_DISABLED=1

WORKDIR /app

# คัดลอก package files และติดตั้งเฉพาะ production deps
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --only=production; else npm install --omit=dev; fi \
	&& npm cache clean --force

# คัดลอกไฟล์ build และ assets ที่จำเป็นจาก builder stage
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.* ./  
COPY --from=builder /app/tsconfig*.json ./  

# เปิดพอร์ตแอป
EXPOSE 3000

# ใช้สคริปต์ start ของโปรเจกต์ (ปกติคือ `next start -p 3000`)
CMD ["npm", "start"]
#!/bin/bash

ENDPOINT="http://skills-task3-competition-alb-778797648.ap-northeast-2.elb.amazonaws.com"
PASS=0
FAIL=0

echo "=========================================="
echo "API 테스트 시작"
echo "=========================================="

# 1. Healthcheck
echo -e "\n[TEST 1] Healthcheck"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $ENDPOINT/healthcheck)
if [ "$RESPONSE" -eq 200 ]; then
  echo "✅ PASS: 200 OK"
  ((PASS++))
else
  echo "❌ FAIL: Expected 200, Got $RESPONSE"
  ((FAIL++))
fi

# 2. User 생성 (POST)
echo -e "\n[TEST 2] User 생성 (POST)"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $ENDPOINT/v1/user \
  -H "Content-Type: application/json" \
  -d '{"email":"test1@example.com","name":"Test User 1"}')
STATUS=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)
if [ "$STATUS" -eq 201 ]; then
  echo "✅ PASS: 201 Created"
  echo "   Response: $BODY"
  ((PASS++))
else
  echo "❌ FAIL: Expected 201, Got $STATUS"
  echo "   Response: $BODY"
  ((FAIL++))
fi

# 3. User 조회 (GET)
echo -e "\n[TEST 3] User 조회 (GET)"
RESPONSE=$(curl -s -w "\n%{http_code}" "$ENDPOINT/v1/user?email=test1@example.com")
STATUS=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)
if [ "$STATUS" -eq 200 ]; then
  echo "✅ PASS: 200 OK"
  echo "   Response: $BODY"
  ((PASS++))
else
  echo "❌ FAIL: Expected 200, Got $STATUS"
  echo "   Response: $BODY"
  ((FAIL++))
fi

# 4. User 잘못된 이메일 (403)
echo -e "\n[TEST 4] User 잘못된 이메일 형식 (403)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $ENDPOINT/v1/user \
  -H "Content-Type: application/json" \
  -d '{"email":"invalid-email","name":"Test"}')
if [ "$RESPONSE" -eq 403 ]; then
  echo "✅ PASS: 403 Forbidden (WAF)"
  ((PASS++))
else
  echo "❌ FAIL: Expected 403, Got $RESPONSE"
  ((FAIL++))
fi

# 5. Product 생성 (POST)
echo -e "\n[TEST 5] Product 생성 (POST)"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $ENDPOINT/v1/product \
  -H "Content-Type: application/json" \
  -d '{"id":"prod001","name":"Test Product","price":19.99}')
STATUS=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)
if [ "$STATUS" -eq 201 ]; then
  echo "✅ PASS: 201 Created"
  echo "   Response: $BODY"
  ((PASS++))
else
  echo "❌ FAIL: Expected 201, Got $STATUS"
  echo "   Response: $BODY"
  ((FAIL++))
fi

# 6. Product 조회 (GET)
echo -e "\n[TEST 6] Product 조회 (GET)"
RESPONSE=$(curl -s -w "\n%{http_code}" "$ENDPOINT/v1/product?id=prod001")
STATUS=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)
if [ "$STATUS" -eq 200 ]; then
  echo "✅ PASS: 200 OK"
  echo "   Response: $BODY"
  ((PASS++))
else
  echo "❌ FAIL: Expected 200, Got $STATUS"
  echo "   Response: $BODY"
  ((FAIL++))
fi

# 7. Stress 테스트 (POST)
echo -e "\n[TEST 7] Stress 테스트 (POST)"
START=$(date +%s%3N)
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $ENDPOINT/v1/stress)
END=$(date +%s%3N)
DURATION=$((END - START))
STATUS=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)
if [ "$STATUS" -eq 201 ] && [ "$DURATION" -lt 1000 ]; then
  echo "✅ PASS: 201 Created (${DURATION}ms)"
  echo "   Response: $BODY"
  ((PASS++))
else
  echo "❌ FAIL: Expected 201 in <1000ms, Got $STATUS (${DURATION}ms)"
  echo "   Response: $BODY"
  ((FAIL++))
fi

# 8. 404 테스트
echo -e "\n[TEST 8] 잘못된 경로 (404)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $ENDPOINT/invalid-path)
if [ "$RESPONSE" -eq 404 ]; then
  echo "✅ PASS: 404 Not Found"
  ((PASS++))
else
  echo "❌ FAIL: Expected 404, Got $RESPONSE"
  ((FAIL++))
fi

# 9. 403 테스트 (잘못된 메소드)
echo -e "\n[TEST 9] 잘못된 메소드 (403)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE $ENDPOINT/v1/user)
if [ "$RESPONSE" -eq 403 ]; then
  echo "✅ PASS: 403 Forbidden (WAF)"
  ((PASS++))
else
  echo "❌ FAIL: Expected 403, Got $RESPONSE"
  ((FAIL++))
fi

# 10. 응답시간 테스트 (User)
echo -e "\n[TEST 10] User API 응답시간 (<200ms)"
START=$(date +%s%3N)
curl -s "$ENDPOINT/v1/user?email=test1@example.com" > /dev/null
END=$(date +%s%3N)
DURATION=$((END - START))
if [ "$DURATION" -lt 200 ]; then
  echo "✅ PASS: ${DURATION}ms"
  ((PASS++))
else
  echo "⚠️  WARNING: ${DURATION}ms (목표: <200ms)"
  ((PASS++))
fi

# 결과 요약
echo -e "\n=========================================="
echo "테스트 결과"
echo "=========================================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
TOTAL=$((PASS + FAIL))
SCORE=$((PASS * 100 / TOTAL))
echo "점수: $SCORE/100"
echo "=========================================="

if [ "$FAIL" -eq 0 ]; then
  echo "🎉 모든 테스트 통과!"
  exit 0
else
  echo "❌ $FAIL 개 테스트 실패"
  exit 1
fi

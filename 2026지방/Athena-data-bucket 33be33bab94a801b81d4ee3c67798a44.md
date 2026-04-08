# Athena-data-bucket

## AWS Athena 실습 명령어 정리

**1단계: 변수 설정**

```html
export REGION="ap-northeast-2"
export TIMESTAMP=$(date +%s)
export DATA_BUCKET="athena-data-bucket-$TIMESTAMP"
export RESULT_BUCKET="athena-result-bucket-$TIMESTAMP"
```

**2단계: S3 버킷 생성 및 확인**

```html
aws s3 mb s3://$DATA_BUCKET --region $REGION
aws s3 mb s3://$RESULT_BUCKET --region $REGION
aws s3 ls | grep athena
```

**3단계: 샘플 CSV 데이터 생성**

```html
cat > sales.csv << 'EOF'
category,product,amount
food,apple,1200
food,banana,2300
book,sql_basic,15000
book,python_basic,22000
it,mouse,18000
it,keyboard,35000
food,orange,1700
book,db_design,27000
it,monitor,210000
EOF
```

**4단계: S3에 데이터 업로드**

```html
aws s3 cp sales.csv s3://$DATA_BUCKET/data/
aws s3 ls s3://$DATA_BUCKET/data/
```

**5단계: Athena 데이터베이스 생성**

```html
export ATHENA_DB="skillsdb"
export ATHENA_TABLE="sales_data"

aws athena start-query-execution \
  --region $REGION \
  --query-string "CREATE DATABASE IF NOT EXISTS $ATHENA_DB" \
  --result-configuration OutputLocation=s3://$RESULT_BUCKET/

sleep 5
```

**6단계: Athena 외부 테이블 생성**

```html
TABLE_QUERY="CREATE EXTERNAL TABLE IF NOT EXISTS ${ATHENA_DB}.${ATHENA_TABLE} (
  category string,
  product string,
  amount int
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3://${DATA_BUCKET}/data/'
TBLPROPERTIES ('skip.header.line.count'='1');"

aws athena start-query-execution \
  --region $REGION \
  --query-string "$TABLE_QUERY" \
  --query-execution-context Database=$ATHENA_DB \
  --result-configuration OutputLocation=s3://$RESULT_BUCKET/

sleep 10
echo "Database and table creation completed!"
```

## 7단계: Athena 쿼리 실행 및 결과 조회

```html
# 카테고리별 총 매출 쿼리 실행
QUERY_ID=$(aws athena start-query-execution \
  --region $REGION \
  --query-string "SELECT category, SUM(amount) AS total_sales FROM $ATHENA_TABLE GROUP BY category ORDER BY category;" \
  --query-execution-context Database=$ATHENA_DB \
  --result-configuration OutputLocation=s3://$RESULT_BUCKET/ \
  --query 'QueryExecutionId' \
  --output text)

echo "Query ID: $QUERY_ID"

# 쿼리 완료 대기
sleep 15

# 결과 조회
aws athena get-query-results \
  --region $REGION \
  --query-execution-id $QUERY_ID \
  --query 'ResultSet.Rows[*].Data[*].VarCharValue' \
  --output table
```

**실행 결과:**

| category | total_sales |
| --- | --- |
| book | 64,000 |
| food | 5,200 |
| it | 263,000 |

![image.png](Athena-data-bucket/image.png)
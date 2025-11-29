FROM flink:1.18-scala_2.12

# Download Flink SQL connectors
RUN mkdir -p /opt/flink/lib && \
    # Kafka connector
    curl -L -o /opt/flink/lib/flink-sql-connector-kafka-3.0.2-1.18.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.0.2-1.18/flink-sql-connector-kafka-3.0.2-1.18.jar && \
    # Avro format
    curl -L -o /opt/flink/lib/flink-sql-avro-1.18.1.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-sql-avro/1.18.1/flink-sql-avro-1.18.1.jar && \
    # Avro Confluent Registry format
    curl -L -o /opt/flink/lib/flink-sql-avro-confluent-registry-1.18.1.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-sql-avro-confluent-registry/1.18.1/flink-sql-avro-confluent-registry-1.18.1.jar && \
    # JSON format
    curl -L -o /opt/flink/lib/flink-json-1.18.1.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-json/1.18.1/flink-json-1.18.1.jar && \
    # JDBC connector for Postgres
    curl -L -o /opt/flink/lib/flink-connector-jdbc-3.1.2-1.18.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.1.2-1.18/flink-connector-jdbc-3.1.2-1.18.jar && \
    # PostgreSQL JDBC driver
    curl -L -o /opt/flink/lib/postgresql-42.7.1.jar \
      https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.1/postgresql-42.7.1.jar && \
    # Iceberg Flink runtime
    curl -L -o /opt/flink/lib/iceberg-flink-runtime-1.18-1.4.3.jar \
      https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-flink-runtime-1.18/1.4.3/iceberg-flink-runtime-1.18-1.4.3.jar && \
    # AWS bundle for S3
    curl -L -o /opt/flink/lib/flink-s3-fs-hadoop-1.18.1.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.18.1/flink-s3-fs-hadoop-1.18.1.jar && \
    # Hadoop AWS for S3A
    curl -L -o /opt/flink/lib/hadoop-aws-3.3.4.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    # AWS SDK bundle
    curl -L -o /opt/flink/lib/aws-java-sdk-bundle-1.12.367.jar \
      https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar

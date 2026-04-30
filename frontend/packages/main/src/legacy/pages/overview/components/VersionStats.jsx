import React from 'react';
import { Card, Progress, Typography, Empty } from 'antd';
import { BranchesOutlined } from '@ant-design/icons';

const { Text } = Typography;

const VersionStats = ({ data }) => {
  const total = data?.total || 0;
  const release = data?.releaseCount || 0;
  const pre = data?.preCount || 0;
  const releasePct = total > 0 ? Math.round((release / total) * 100) : 0;

  return (
    <Card
      title={<span><BranchesOutlined style={{ marginRight: 8 }} />Prompt 版本分布</span>}
      size="small"
      style={{ borderRadius: 8, height: '100%' }}
    >
      {total === 0 ? (
        <Empty description="暂无版本数据" image={Empty.PRESENTED_IMAGE_SIMPLE} style={{ margin: '24px 0' }} />
      ) : (
        <>
          <div style={{ marginBottom: 20 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <Text style={{ fontSize: 13 }}>正式版本（release）</Text>
              <Text style={{ fontWeight: 600 }}>{release}</Text>
            </div>
            <Progress
              percent={releasePct}
              strokeColor="#52c41a"
              trailColor="#e6f7ff"
              showInfo={false}
              size="small"
            />
          </div>

          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <Text style={{ fontSize: 13 }}>预发版本（pre）</Text>
              <Text style={{ fontWeight: 600 }}>{pre}</Text>
            </div>
            <Progress
              percent={total > 0 ? Math.round((pre / total) * 100) : 0}
              strokeColor="#722ed1"
              trailColor="#f9f0ff"
              showInfo={false}
              size="small"
            />
          </div>

          <div style={{
            marginTop: 20, padding: '12px 16px', borderRadius: 6,
            backgroundColor: '#fafafa', textAlign: 'center',
          }}>
            <Text style={{ fontSize: 13, color: '#8c8c8c' }}>版本总数</Text>
            <div style={{ fontSize: 28, fontWeight: 700, color: '#262626', lineHeight: 1.2, marginTop: 4 }}>
              {total}
            </div>
          </div>
        </>
      )}
    </Card>
  );
};

export default VersionStats;

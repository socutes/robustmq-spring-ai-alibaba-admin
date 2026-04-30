import React from 'react';
import { Card, Timeline, Typography, Tag, Empty } from 'antd';
import { ClockCircleOutlined, FileTextOutlined, ExperimentOutlined } from '@ant-design/icons';

const { Text } = Typography;

const EVENT_CONFIG = {
  PROMPT_VERSION_PUBLISHED: {
    color: '#1890ff',
    icon: <FileTextOutlined />,
    tagColor: 'blue',
    tagText: 'Prompt',
  },
  EXPERIMENT_UPDATED: {
    color: '#fa8c16',
    icon: <ExperimentOutlined />,
    tagColor: 'orange',
    tagText: '实验',
  },
};

const formatTime = (ts) => {
  if (!ts) return '';
  const d = new Date(ts);
  const now = new Date();
  const diff = now - d;
  if (diff < 60000) return '刚刚';
  if (diff < 3600000) return `${Math.floor(diff / 60000)} 分钟前`;
  if (diff < 86400000) return `${Math.floor(diff / 3600000)} 小时前`;
  return d.toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
};

const RecentActivity = ({ data }) => {
  const items = data || [];

  return (
    <Card
      title={<span><ClockCircleOutlined style={{ marginRight: 8 }} />最近活动</span>}
      size="small"
      style={{ borderRadius: 8, height: '100%' }}
      bodyStyle={{ maxHeight: 320, overflowY: 'auto' }}
    >
      {items.length === 0 ? (
        <Empty description="暂无活动记录" image={Empty.PRESENTED_IMAGE_SIMPLE} style={{ margin: '24px 0' }} />
      ) : (
        <Timeline
          style={{ marginTop: 8 }}
          items={items.map((item) => {
            const config = EVENT_CONFIG[item.eventType] || { color: '#8c8c8c', tagColor: 'default', tagText: '事件' };
            return {
              color: config.color,
              dot: config.icon,
              children: (
                <div style={{ paddingBottom: 4 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                    <Tag color={config.tagColor} style={{ margin: 0, fontSize: 11 }}>{config.tagText}</Tag>
                    <Text style={{ fontSize: 13 }}>{item.description}</Text>
                  </div>
                  <Text style={{ fontSize: 12, color: '#8c8c8c' }}>{formatTime(item.timestamp)}</Text>
                </div>
              ),
            };
          })}
        />
      )}
    </Card>
  );
};

export default RecentActivity;

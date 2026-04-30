import React from 'react';
import { Card, Typography, Empty } from 'antd';
import { ExperimentOutlined } from '@ant-design/icons';

const { Text } = Typography;

const STATUS_CONFIG = [
  { key: 'completedCount', label: '已完成', color: '#52c41a' },
  { key: 'runningCount',   label: '运行中', color: '#1890ff' },
  { key: 'failedCount',    label: '失败',   color: '#ff4d4f' },
  { key: 'draftCount',     label: '草稿',   color: '#8c8c8c' },
  { key: 'stoppedCount',   label: '已停止', color: '#faad14' },
];

const ExperimentStatusChart = ({ data }) => {
  const total = data?.total || 0;

  const segments = STATUS_CONFIG.map(s => ({
    ...s,
    count: data?.[s.key] || 0,
    pct: total > 0 ? Math.round(((data?.[s.key] || 0) / total) * 100) : 0,
  })).filter(s => s.count > 0);

  return (
    <Card
      title={<span><ExperimentOutlined style={{ marginRight: 8 }} />实验状态分布</span>}
      size="small"
      style={{ borderRadius: 8, height: '100%' }}
    >
      {total === 0 ? (
        <Empty description="暂无实验数据" image={Empty.PRESENTED_IMAGE_SIMPLE} style={{ margin: '24px 0' }} />
      ) : (
        <>
          {/* 进度条 */}
          <div style={{ display: 'flex', borderRadius: 6, overflow: 'hidden', height: 20, marginBottom: 20 }}>
            {segments.map(s => (
              <div
                key={s.key}
                title={`${s.label}: ${s.count}`}
                style={{ width: `${s.pct}%`, backgroundColor: s.color, minWidth: s.count > 0 ? 4 : 0 }}
              />
            ))}
          </div>

          {/* 图例 */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px 16px' }}>
            {STATUS_CONFIG.map(s => {
              const count = data?.[s.key] || 0;
              const pct = total > 0 ? Math.round((count / total) * 100) : 0;
              return (
                <div key={s.key} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ width: 10, height: 10, borderRadius: 2, backgroundColor: s.color, flexShrink: 0 }} />
                  <Text style={{ fontSize: 13, color: '#8c8c8c', flex: 1 }}>{s.label}</Text>
                  <Text style={{ fontSize: 13, fontWeight: 500 }}>{count}</Text>
                  <Text style={{ fontSize: 12, color: '#8c8c8c' }}>({pct}%)</Text>
                </div>
              );
            })}
          </div>

          <div style={{ textAlign: 'center', marginTop: 16, color: '#8c8c8c', fontSize: 13 }}>
            共 <span style={{ fontWeight: 600, color: '#262626' }}>{total}</span> 个实验
          </div>
        </>
      )}
    </Card>
  );
};

export default ExperimentStatusChart;

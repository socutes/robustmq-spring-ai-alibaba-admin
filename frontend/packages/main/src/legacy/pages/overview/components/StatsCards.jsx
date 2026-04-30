import React from 'react';
import { Row, Col, Card, Statistic } from 'antd';
import {
  FileTextOutlined,
  BranchesOutlined,
  ExperimentOutlined,
  DatabaseOutlined,
  BarChartOutlined,
  RiseOutlined,
} from '@ant-design/icons';

const StatsCards = ({ data }) => {
  const cards = [
    {
      title: 'Prompt 总数',
      value: data?.prompts?.total ?? '-',
      suffix: data?.prompts?.addedThisMonth != null
        ? <span style={{ fontSize: 12, color: '#52c41a' }}>+{data.prompts.addedThisMonth} 本月</span>
        : null,
      icon: <FileTextOutlined style={{ fontSize: 24, color: '#1890ff' }} />,
      color: '#1890ff',
    },
    {
      title: 'Prompt 版本',
      value: data?.promptVersions?.total ?? '-',
      suffix: data?.promptVersions
        ? <span style={{ fontSize: 12, color: '#8c8c8c' }}>
            release {data.promptVersions.releaseCount} / pre {data.promptVersions.preCount}
          </span>
        : null,
      icon: <BranchesOutlined style={{ fontSize: 24, color: '#722ed1' }} />,
      color: '#722ed1',
    },
    {
      title: '实验',
      value: data?.experiments?.total ?? '-',
      suffix: data?.experiments?.runningCount > 0
        ? <span style={{ fontSize: 12, color: '#1890ff' }}>运行中 {data.experiments.runningCount}</span>
        : null,
      icon: <ExperimentOutlined style={{ fontSize: 24, color: '#fa8c16' }} />,
      color: '#fa8c16',
    },
    {
      title: '数据集',
      value: data?.datasets?.total ?? '-',
      icon: <DatabaseOutlined style={{ fontSize: 24, color: '#13c2c2' }} />,
      color: '#13c2c2',
    },
    {
      title: '评估器',
      value: data?.evaluators?.total ?? '-',
      icon: <BarChartOutlined style={{ fontSize: 24, color: '#52c41a' }} />,
      color: '#52c41a',
    },
  ];

  return (
    <Row gutter={16}>
      {cards.map((card, index) => (
        <Col key={index} xs={24} sm={12} md={8} lg={8} xl={4} style={{ marginBottom: 0 }}>
          <Card
            size="small"
            style={{ borderRadius: 8 }}
            bodyStyle={{ padding: '16px 20px' }}
          >
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
              <div>
                <div style={{ color: '#8c8c8c', fontSize: 13, marginBottom: 8 }}>{card.title}</div>
                <div style={{ fontSize: 28, fontWeight: 600, color: card.color, lineHeight: 1 }}>
                  {card.value}
                </div>
                {card.suffix && <div style={{ marginTop: 6 }}>{card.suffix}</div>}
              </div>
              <div style={{
                width: 44, height: 44, borderRadius: 8,
                backgroundColor: card.color + '15',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                {card.icon}
              </div>
            </div>
          </Card>
        </Col>
      ))}
    </Row>
  );
};

export default StatsCards;

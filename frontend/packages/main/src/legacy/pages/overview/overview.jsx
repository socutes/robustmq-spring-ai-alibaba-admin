import React, { useState, useEffect } from 'react';
import { Row, Col, Spin, Button, Typography, Space } from 'antd';
import { ReloadOutlined, DashboardOutlined } from '@ant-design/icons';
import { getDashboardOverview } from '../../services/dashboard';
import StatsCards from './components/StatsCards';
import ExperimentStatusChart from './components/ExperimentStatusChart';
import VersionStats from './components/VersionStats';
import RecentActivity from './components/RecentActivity';

const { Title, Text } = Typography;

const OverviewPage = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState(null);

  const fetchData = () => {
    setLoading(true);
    getDashboardOverview()
      .then((res) => {
        if (res.code === 200) {
          setData(res.data);
          setLastUpdated(new Date());
        }
      })
      .catch((err) => {
        console.error('获取 overview 数据失败:', err);
      })
      .finally(() => {
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchData();
  }, []);

  return (
    <div style={{ padding: 24, minHeight: '100%' }}>
      {/* 页头 */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <Space align="center">
          <DashboardOutlined style={{ fontSize: 22, color: '#1890ff' }} />
          <Title level={4} style={{ margin: 0 }}>数据总览</Title>
          {lastUpdated && (
            <Text style={{ fontSize: 12, color: '#8c8c8c' }}>
              更新于 {lastUpdated.toLocaleTimeString('zh-CN')}
            </Text>
          )}
        </Space>
        <Button
          icon={<ReloadOutlined />}
          onClick={fetchData}
          loading={loading}
          size="small"
        >
          刷新
        </Button>
      </div>

      <Spin spinning={loading}>
        {/* 指标卡 */}
        <div style={{ marginBottom: 24 }}>
          <StatsCards data={data} />
        </div>

        {/* 图表行 */}
        <Row gutter={16} style={{ marginBottom: 16 }}>
          <Col span={12}>
            <ExperimentStatusChart data={data?.experiments} />
          </Col>
          <Col span={12}>
            <VersionStats data={data?.promptVersions} />
          </Col>
        </Row>

        {/* 最近活动 */}
        <Row gutter={16}>
          <Col span={24}>
            <RecentActivity data={data?.recentActivity} />
          </Col>
        </Row>
      </Spin>
    </div>
  );
};

export default OverviewPage;

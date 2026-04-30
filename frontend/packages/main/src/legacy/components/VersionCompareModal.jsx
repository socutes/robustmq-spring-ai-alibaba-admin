import React from 'react';
import {
  Modal,
  Card,
  Typography,
  Row,
  Col,
  Space,
  Tag,
  Empty,
  Button
} from 'antd';
import {
  ArrowLeftOutlined,
  ArrowRightOutlined,
  CloseOutlined,
  SettingOutlined,
  FileTextOutlined,
  PlusOutlined,
  MinusOutlined,
  EditOutlined
} from '@ant-design/icons';

const { Title, Text } = Typography;

const VersionCompareModal = ({ prompt, diffResult, onClose }) => {
  const { versionA, versionB, diffs } = diffResult;

  const renderDiffLines = (oldText, newText) => {
    const safeOldText = oldText || '';
    const safeNewText = newText || '';
    const oldLines = safeOldText.split('\n');
    const newLines = safeNewText.split('\n');
    const maxLines = Math.max(oldLines.length, newLines.length);

    const result = [];
    for (let i = 0; i < maxLines; i++) {
      const oldLine = oldLines[i] || '';
      const newLine = newLines[i] || '';

      if (oldLine === newLine) {
        result.push({ type: 'unchanged', oldLine, newLine, lineNumber: i + 1 });
      } else if (oldLine && !newLine) {
        result.push({ type: 'removed', oldLine, newLine: '', lineNumber: i + 1 });
      } else if (!oldLine && newLine) {
        result.push({ type: 'added', oldLine: '', newLine, lineNumber: i + 1 });
      } else {
        result.push({ type: 'modified', oldLine, newLine, lineNumber: i + 1 });
      }
    }
    return result;
  };

  const diffLines = renderDiffLines(diffs.template.valueA, diffs.template.valueB);

  const modelConfigA = diffs.modelConfig.valueA ? (() => { try { return JSON.parse(diffs.modelConfig.valueA); } catch { return null; } })() : null;
  const modelConfigB = diffs.modelConfig.valueB ? (() => { try { return JSON.parse(diffs.modelConfig.valueB); } catch { return null; } })() : null;

  return (
    <Modal
      title={
        <div>
          <Title level={4} style={{ margin: 0 }}>
            版本对比 - {prompt.promptKey || prompt.name || '未知Prompt'}
          </Title>
          <div style={{ display: 'flex', alignItems: 'center', gap: 24, marginTop: 16, fontSize: '14px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ width: 16, height: 16, backgroundColor: '#fff2f0', borderLeft: '4px solid #ff7875', borderRadius: 2 }}></div>
              <Text type="secondary">删除的内容</Text>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ width: 16, height: 16, backgroundColor: '#f6ffed', borderLeft: '4px solid #73d13d', borderRadius: 2 }}></div>
              <Text type="secondary">新增的内容</Text>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ width: 16, height: 16, backgroundColor: '#fffbe6', borderLeft: '4px solid #fadb14', borderRadius: 2 }}></div>
              <Text type="secondary">修改的内容</Text>
            </div>
          </div>
        </div>
      }
      open={true}
      onCancel={onClose}
      width={1400}
      style={{ top: 20, maxHeight: 'calc(100vh - 40px)' }}
      bodyStyle={{ maxHeight: 'calc(100vh - 200px)', overflowY: 'auto', padding: 24 }}
      footer={[
        <Button key="close" type="primary" onClick={onClose}>关闭对比</Button>
      ]}
      closeIcon={<CloseOutlined />}
    >
      <Space direction="vertical" size={24} style={{ width: '100%' }}>
        {/* 版本信息 */}
        <Row gutter={24}>
          <Col span={12}>
            <Card size="small">
              <Title level={5} style={{ margin: 0, marginBottom: 12, display: 'flex', alignItems: 'center' }}>
                <ArrowLeftOutlined style={{ color: '#1890ff', marginRight: 8 }} />
                版本 A: {versionA.version}
              </Title>
              <Space direction="vertical" size={8} style={{ width: '100%' }}>
                <div>
                  <Text strong>创建时间：</Text>
                  <Text style={{ marginLeft: 8 }}>
                    {versionA.createTime ? new Date(versionA.createTime).toLocaleString('zh-CN') : '未知'}
                  </Text>
                </div>
                <div>
                  <Text strong>状态：</Text>
                  <Tag style={{ marginLeft: 8 }} color={versionA.status === 'release' ? 'success' : 'warning'}>
                    {versionA.status === 'release' ? '正式版本' : 'PRE版本'}
                  </Tag>
                </div>
              </Space>
            </Card>
          </Col>
          <Col span={12}>
            <Card size="small">
              <Title level={5} style={{ margin: 0, marginBottom: 12, display: 'flex', alignItems: 'center' }}>
                <ArrowRightOutlined style={{ color: '#52c41a', marginRight: 8 }} />
                版本 B: {versionB.version}
              </Title>
              <Space direction="vertical" size={8} style={{ width: '100%' }}>
                <div>
                  <Text strong>创建时间：</Text>
                  <Text style={{ marginLeft: 8 }}>
                    {versionB.createTime ? new Date(versionB.createTime).toLocaleString('zh-CN') : '未知'}
                  </Text>
                </div>
                <div>
                  <Text strong>状态：</Text>
                  <Tag style={{ marginLeft: 8 }} color={versionB.status === 'release' ? 'success' : 'warning'}>
                    {versionB.status === 'release' ? '正式版本' : 'PRE版本'}
                  </Tag>
                </div>
              </Space>
            </Card>
          </Col>
        </Row>

        {/* 模型配置对比 */}
        <Card
          title={<div style={{ display: 'flex', alignItems: 'center' }}><SettingOutlined style={{ marginRight: 8 }} />模型配置对比</div>}
          size="small"
        >
          {(modelConfigA || modelConfigB) ? (
            <Row gutter={24}>
              <Col span={12}>
                <Title level={5} style={{ marginBottom: 12 }}>版本 A 配置</Title>
                {modelConfigA ? (
                  <Space direction="vertical" size={8} style={{ width: '100%' }}>
                    {Object.entries(modelConfigA).map(([key, val]) => (
                      <div key={key} style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <Text type="secondary">{key}：</Text>
                        <Text>{String(val)}</Text>
                      </div>
                    ))}
                  </Space>
                ) : <Text type="secondary">无模型配置</Text>}
              </Col>
              <Col span={12}>
                <Title level={5} style={{ marginBottom: 12 }}>版本 B 配置</Title>
                {modelConfigB ? (
                  <Space direction="vertical" size={8} style={{ width: '100%' }}>
                    {Object.entries(modelConfigB).map(([key, val]) => {
                      const changed = modelConfigA?.[key] !== val;
                      return (
                        <div key={key} style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <Text type="secondary">{key}：</Text>
                          <Text strong={changed} style={{ color: changed ? '#52c41a' : undefined }}>{String(val)}</Text>
                        </div>
                      );
                    })}
                  </Space>
                ) : <Text type="secondary">无模型配置</Text>}
              </Col>
            </Row>
          ) : (
            <Empty image={<SettingOutlined style={{ fontSize: 48, color: '#d9d9d9' }} />} description="两个版本都没有模型配置" style={{ padding: '32px 0' }} />
          )}
        </Card>

        {/* 内容对比 */}
        <Card
          title={<div style={{ display: 'flex', alignItems: 'center' }}><FileTextOutlined style={{ marginRight: 8 }} />内容对比</div>}
          size="small"
        >
          <div style={{ maxHeight: 384, overflowY: 'auto', border: '1px solid #f0f0f0', borderRadius: 6 }}>
            {diffLines.length > 0 ? (
              <div style={{ fontFamily: 'monospace', fontSize: '13px' }}>
                {diffLines.map((line, index) => {
                  const getLineStyle = (type) => {
                    const baseStyle = { display: 'grid', gridTemplateColumns: '50px 40px 1fr 1fr', borderBottom: '1px solid #f0f0f0' };
                    switch (type) {
                      case 'added':    return { ...baseStyle, backgroundColor: '#f6ffed', borderLeft: '4px solid #73d13d' };
                      case 'removed':  return { ...baseStyle, backgroundColor: '#fff2f0', borderLeft: '4px solid #ff7875' };
                      case 'modified': return { ...baseStyle, backgroundColor: '#fffbe6', borderLeft: '4px solid #fadb14' };
                      default:         return { ...baseStyle, backgroundColor: '#ffffff' };
                    }
                  };
                  const getIcon = (type) => {
                    switch (type) {
                      case 'added':    return <PlusOutlined style={{ color: '#52c41a', fontSize: '12px' }} />;
                      case 'removed':  return <MinusOutlined style={{ color: '#ff4d4f', fontSize: '12px' }} />;
                      case 'modified': return <EditOutlined style={{ color: '#faad14', fontSize: '12px' }} />;
                      default:         return null;
                    }
                  };
                  return (
                    <div key={index} style={getLineStyle(line.type)}>
                      <div style={{ padding: '4px 8px', textAlign: 'center', backgroundColor: '#fafafa', borderRight: '1px solid #f0f0f0', color: '#8c8c8c', fontSize: '12px' }}>
                        {line.lineNumber}
                      </div>
                      <div style={{ padding: '4px 8px', textAlign: 'center', borderRight: '1px solid #f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        {getIcon(line.type)}
                      </div>
                      <div style={{ padding: '4px 12px', borderRight: '1px solid #f0f0f0', color: '#262626', whiteSpace: 'pre-wrap' }}>
                        {line.type === 'added' ? (
                          <Text type="secondary" italic>（新增行）</Text>
                        ) : (
                          <span style={{ textDecoration: line.type === 'removed' || line.type === 'modified' ? 'line-through' : 'none', color: line.type === 'removed' || line.type === 'modified' ? '#ff4d4f' : '#262626' }}>
                            {line.oldLine || ' '}
                          </span>
                        )}
                      </div>
                      <div style={{ padding: '4px 12px', color: '#262626', whiteSpace: 'pre-wrap' }}>
                        {line.type === 'removed' ? (
                          <Text type="secondary" italic>（删除行）</Text>
                        ) : (
                          <span style={{ color: line.type === 'added' || line.type === 'modified' ? '#52c41a' : '#262626', fontWeight: line.type === 'added' || line.type === 'modified' ? 'bold' : 'normal' }}>
                            {line.newLine || ' '}
                          </span>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <Empty image={<FileTextOutlined style={{ fontSize: 48, color: '#d9d9d9' }} />} description="两个版本的内容完全相同" style={{ padding: '32px 0' }} />
            )}
          </div>
        </Card>
      </Space>
    </Modal>
  );
};

export default VersionCompareModal;

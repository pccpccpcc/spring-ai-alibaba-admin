import React, { useEffect, useState } from 'react';
import {
  Modal,
  Card,
  Typography,
  Row,
  Col,
  Space,
  Empty,
  Button,
  Spin,
  Alert,
} from 'antd';
import {
  ArrowLeftOutlined,
  ArrowRightOutlined,
  CloseOutlined,
  PlusOutlined,
  MinusOutlined,
} from '@ant-design/icons';
import { getPromptVersionDiff } from '../services/prompt';

const { Title, Text } = Typography;

// 行级配色（复用原组件配色语言）
const LINE_STYLE = {
  add: { bg: '#f6ffed', border: '#73d13d', color: '#52c41a' },
  remove: { bg: '#fff2f0', border: '#ff7875', color: '#ff4d4f' },
  equal: { bg: '#ffffff', border: '#f0f0f0', color: '#262626' },
  context: { bg: '#fafafa', border: '#f0f0f0', color: '#8c8c8c' },
};

const FIELD_LABEL = {
  template: 'Prompt 模板',
  variables: '变量',
  modelConfig: '模型配置',
};

const VersionCompareModal = ({ promptKey, versionA, versionB, onClose }) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [diff, setDiff] = useState(null);

  useEffect(() => {
    if (!promptKey || !versionA || !versionB) {
      return;
    }
    setLoading(true);
    setError(null);
    setDiff(null);
    getPromptVersionDiff({ promptKey, versionA, versionB })
      .then((res) => {
        if (res?.data) {
          setDiff(res.data);
        } else {
          setError(res?.message || '对比结果为空');
        }
      })
      .catch((e) => setError(e?.message || '对比失败，请稍后重试'))
      .finally(() => setLoading(false));
  }, [promptKey, versionA, versionB]);

  const renderHunks = (hunks) => {
    if (!hunks || hunks.length === 0) {
      return (
        <Empty
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description="无差异"
          style={{ padding: '16px 0' }}
        />
      );
    }
    return (
      <div style={{ fontFamily: 'monospace', fontSize: '13px', border: '1px solid #f0f0f0', borderRadius: 6 }}>
        {hunks.map((hunk, idx) => {
          const s = LINE_STYLE[hunk.type] || LINE_STYLE.equal;
          return (
            <div
              key={idx}
              style={{
                display: 'grid',
                gridTemplateColumns: '56px 24px 1fr',
                backgroundColor: s.bg,
                borderLeft: `4px solid ${s.border}`,
                borderBottom: idx < hunks.length - 1 ? '1px solid #f0f0f0' : 'none',
              }}
            >
              <div
                style={{
                  padding: '4px 8px',
                  textAlign: 'center',
                  backgroundColor: '#fafafa',
                  borderRight: '1px solid #f0f0f0',
                  color: '#8c8c8c',
                  fontSize: '12px',
                }}
              >
                {hunk.type === 'add' ? hunk.newStart : hunk.oldStart}
              </div>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: s.color,
                }}
              >
                {hunk.type === 'add' ? (
                  <PlusOutlined style={{ fontSize: '12px' }} />
                ) : hunk.type === 'remove' ? (
                  <MinusOutlined style={{ fontSize: '12px' }} />
                ) : null}
              </div>
              <div style={{ padding: '4px 12px', whiteSpace: 'pre-wrap', color: s.color }}>
                {(hunk.lines || []).join('\n')}
              </div>
            </div>
          );
        })}
      </div>
    );
  };

  const renderMeta = (meta, label, version, arrowIcon) => (
    <Card size="small">
      <Title level={5} style={{ margin: 0, marginBottom: 12, display: 'flex', alignItems: 'center' }}>
        {arrowIcon}
        {label}: {version}
      </Title>
      <Space direction="vertical" size={8} style={{ width: '100%' }}>
        <div>
          <Text strong>创建时间：</Text>
          <Text style={{ marginLeft: 8 }}>
            {meta?.createTime ? new Date(meta.createTime).toLocaleString('zh-CN') : '未知'}
          </Text>
        </div>
        <div>
          <Text strong>说明：</Text>
          <Text style={{ marginLeft: 8 }}>{meta?.versionDescription || '无说明'}</Text>
        </div>
        <div>
          <Text strong>状态：</Text>
          <Text style={{ marginLeft: 8 }}>{meta?.status || '-'}</Text>
        </div>
        <div>
          <Text strong>前置版本：</Text>
          <Text style={{ marginLeft: 8 }}>{meta?.previousVersion || '-'}</Text>
        </div>
      </Space>
    </Card>
  );

  return (
    <Modal
      title={
        <div>
          <Title level={4} style={{ margin: 0 }}>
            版本对比 - {promptKey || '未知 Prompt'}（{versionA} → {versionB}）
          </Title>
          <div style={{ display: 'flex', alignItems: 'center', gap: 24, marginTop: 12, fontSize: '14px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ width: 16, height: 16, backgroundColor: '#fff2f0', borderLeft: '4px solid #ff7875', borderRadius: 2 }} />
              <Text type="secondary">删除的内容</Text>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ width: 16, height: 16, backgroundColor: '#f6ffed', borderLeft: '4px solid #73d13d', borderRadius: 2 }} />
              <Text type="secondary">新增的内容</Text>
            </div>
          </div>
        </div>
      }
      open={true}
      onCancel={onClose}
      width={1200}
      style={{ top: 20, maxHeight: 'calc(100vh - 40px)' }}
      bodyStyle={{ maxHeight: 'calc(100vh - 200px)', overflowY: 'auto', padding: 24 }}
      footer={[
        <Button key="close" type="primary" onClick={onClose}>
          关闭对比
        </Button>,
      ]}
      closeIcon={<CloseOutlined />}
    >
      {loading ? (
        <div style={{ textAlign: 'center', padding: '80px 0' }}>
          <Spin tip="加载对比中..." size="large" />
        </div>
      ) : error ? (
        <Alert type="error" message="对比失败" description={error} showIcon style={{ margin: '24px 0' }} />
      ) : !diff ? null : (
        <Space direction="vertical" size={24} style={{ width: '100%' }}>
          {/* 版本元信息 */}
          <Row gutter={24}>
            <Col span={12}>
              {renderMeta(
                diff.metaA,
                '旧版本',
                versionA,
                <ArrowLeftOutlined style={{ color: '#1890ff', marginRight: 8 }} />,
              )}
            </Col>
            <Col span={12}>
              {renderMeta(
                diff.metaB,
                '新版本',
                versionB,
                <ArrowRightOutlined style={{ color: '#52c41a', marginRight: 8 }} />,
              )}
            </Col>
          </Row>

          {/* 内容字段差异：template / variables / modelConfig */}
          {!diff.anyChange ? (
            <Empty description="两个版本内容完全相同" style={{ padding: '40px 0' }} />
          ) : (
            diff.fields.map((f) => (
              <Card
                key={f.field}
                size="small"
                title={
                  <Space>
                    <Text strong>{FIELD_LABEL[f.field] || f.field}</Text>
                    {!f.changed ? <Text type="secondary">（无差异）</Text> : null}
                  </Space>
                }
              >
                {renderHunks(f.hunks)}
              </Card>
            ))
          )}
        </Space>
      )}
    </Modal>
  );
};

export default VersionCompareModal;

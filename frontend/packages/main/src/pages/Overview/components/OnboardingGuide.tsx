import React from 'react';
import { Card, Typography, Button, Space, Row, Col } from 'antd';
import { RocketOutlined, CheckCircleFilled } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';

const { Title, Text } = Typography;

export interface GuideStep {
  key: string;
  icon: React.ReactNode;
  title: string;
  desc: string;
  cta: string;
  path: string;
  done: boolean;
}

/**
 * 新手引导卡片（Overview 空状态时显示）。
 * 3 步引导：配置模型 → 建 Prompt → 建应用，done 状态 + CTA。
 * 见 docs/requirements/overview.md。
 */
const OnboardingGuide: React.FC<{ steps: GuideStep[] }> = ({ steps }) => {
  const navigate = useNavigate();
  const allDone = steps.every((s) => s.done);

  return (
    <Card
      style={{
        background: 'linear-gradient(135deg, #e6f4ff 0%, #f6ffed 100%)',
        border: 'none',
        marginBottom: 24,
      }}
    >
      <Space direction="vertical" size="large" style={{ width: '100%' }}>
        <div>
          <Title level={4} style={{ margin: 0 }}>
            <RocketOutlined style={{ marginRight: 8, color: '#1677ff' }} />
            {allDone ? '欢迎使用 Agent Studio' : '👋 欢迎使用 Agent Studio，3 步快速上手'}
          </Title>
          {!allDone && (
            <Text type="secondary">按顺序完成以下步骤，即可开始构建你的 AI Agent</Text>
          )}
        </div>

        <Row gutter={[16, 16]}>
          {steps.map((s, i) => (
            <Col xs={24} sm={12} md={8} key={s.key}>
              <Card size="small" style={{ height: '100%', opacity: s.done ? 0.6 : 1 }}>
                <Space direction="vertical" size="small" style={{ width: '100%' }}>
                  <Space>
                    <div
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: '50%',
                        background: s.done ? '#52c41a' : '#1677ff',
                        color: '#fff',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: 13,
                        fontWeight: 600,
                      }}
                    >
                      {s.done ? <CheckCircleFilled /> : i + 1}
                    </div>
                    <Text strong>{s.title}</Text>
                  </Space>
                  <Text type="secondary" style={{ fontSize: 12, minHeight: 40, display: 'block' }}>
                    {s.desc}
                  </Text>
                  <Button
                    type={s.done ? 'default' : 'primary'}
                    size="small"
                    block
                    disabled={s.done}
                    icon={s.icon}
                    onClick={() => navigate(s.path)}
                  >
                    {s.done ? '已完成' : s.cta}
                  </Button>
                </Space>
              </Card>
            </Col>
          ))}
        </Row>
      </Space>
    </Card>
  );
};

export default OnboardingGuide;

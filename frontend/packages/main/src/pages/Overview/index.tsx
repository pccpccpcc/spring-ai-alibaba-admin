import React, { useEffect, useState, useCallback } from 'react';
import { Card, Typography, Row, Col, Spin, Button, Space, Tag } from 'antd';
import { ReloadOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import OnboardingGuide, { GuideStep } from './components/OnboardingGuide';
import { getPrompts } from '@/legacy/services/prompt';
import { getExperiments } from '@/legacy/services/evaluators';
import { listProviders } from '@/services/modelService';
import { getAppList } from '@/services/appManage';
import { getKnowledgeList } from '@/services/knowledge';

const { Title, Text } = Typography;

/** 功能地图模块（有 countKey 的带计数，否则只入口，D1/计数策略） */
const MODULES: Array<{ key: string; name: string; desc: string; path: string; countKey: string | null }> = [
  { key: 'prompt', name: 'Prompt 工程', desc: '提示词管理与在线调试', path: '/admin/prompts', countKey: 'prompt' },
  { key: 'experiment', name: '评测·实验', desc: '评测实验与结果分析', path: '/admin/evaluation/experiment', countKey: 'experiment' },
  { key: 'app', name: '应用·工作流', desc: 'Agent 应用与工作流编排', path: '/app', countKey: 'app' },
  { key: 'knowledge', name: '知识库', desc: '文档检索与 RAG', path: '/knowledge', countKey: 'knowledge' },
  { key: 'mcp', name: 'MCP', desc: 'MCP Server 管理', path: '/mcp', countKey: null },
  { key: 'component', name: '组件·插件', desc: '插件与工具', path: '/component', countKey: null },
  { key: 'tracing', name: '可观测', desc: 'Trace 链路追踪', path: '/admin/tracing', countKey: null },
  { key: 'modelService', name: '模型服务', desc: 'Provider / Model 配置', path: '/setting/modelService', countKey: null },
  { key: 'playground', name: 'Playground', desc: '在线对话调试', path: '/admin/playground', countKey: null },
];

/** 从各异返回里容错取计数（legacy Result.data.totalCount / 分页 total / 数组 length） */
const pickCount = (r: any): number | null => {
  if (r == null) return null;
  if (typeof r === 'number') return r;
  if (Array.isArray(r)) return r.length;
  const v = r?.data?.totalCount ?? r?.data?.total ?? r?.totalCount ?? r?.total ?? null;
  return v;
};

const Overview: React.FC = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [counts, setCounts] = useState<Record<string, number | null>>({});
  const [providerDone, setProviderDone] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    const next: Record<string, number | null> = {};
    let providerOk = false;
    // 并行调 5 接口，单个失败（D3）记 null，不阻塞其他
    await Promise.allSettled([
      getPrompts({ pageNo: 1, pageSize: 1 } as any)
        .then((r: any) => { next.prompt = pickCount(r); })
        .catch(() => { next.prompt = null; }),
      getExperiments({ pageNo: 1, pageSize: 1 } as any)
        .then((r: any) => { next.experiment = pickCount(r); })
        .catch(() => { next.experiment = null; }),
      getAppList({ page: 1, size: 1 } as any)
        .then((r: any) => { next.app = pickCount(r); })
        .catch(() => { next.app = null; }),
      getKnowledgeList({ pageNo: 1, pageSize: 1 } as any)
        .then((r: any) => { next.knowledge = pickCount(r); })
        .catch(() => { next.knowledge = null; }),
      listProviders()
        .then((r: any) => {
          const list = r?.data ?? r;
          providerOk = Array.isArray(list) ? list.length > 0 : false;
        })
        .catch(() => { providerOk = false; }),
    ]);
    setCounts(next);
    setProviderDone(providerOk);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const promptCount = counts.prompt;
  const appCount = counts.app;
  // 全空 → 显示引导卡片
  const allEmpty = !providerDone && promptCount === 0 && appCount === 0;

  const guideSteps: GuideStep[] = [
    { key: 'model', icon: <span>⚙️</span>, title: '配置模型服务', desc: '连一个 AI 模型（OpenAI/DashScope/DeepSeek），调试和应用都依赖它', cta: '去配置', path: '/setting/modelService', done: providerDone },
    { key: 'prompt', icon: <span>📝</span>, title: '创建第一个 Prompt', desc: '写一段提示词，在线调试效果', cta: '新建 Prompt', path: '/admin/prompts', done: (promptCount ?? 0) > 0 },
    { key: 'app', icon: <span>🧩</span>, title: '搭建应用 / 工作流', desc: '把 Prompt 组装成可调用的 Agent', cta: '新建应用', path: '/app', done: (appCount ?? 0) > 0 },
  ];

  return (
    <div style={{ padding: 24 }}>
      <div style={{ marginBottom: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title level={3} style={{ margin: 0 }}>Agent Studio 总览</Title>
        <Button icon={<ReloadOutlined />} onClick={load} loading={loading}>
          刷新
        </Button>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: 80 }}>
          <Spin size="large" />
        </div>
      ) : (
        <>
          {allEmpty && <OnboardingGuide steps={guideSteps} />}

          <Title level={5} style={{ marginTop: 8 }}>
            功能地图
          </Title>
          <Row gutter={[16, 16]}>
            {MODULES.map((m) => {
              const count = m.countKey ? counts[m.countKey] : undefined;
              return (
                <Col xs={24} sm={12} md={8} lg={6} key={m.key}>
                  <Card
                    hoverable
                    onClick={() => navigate(m.path)}
                    style={{ height: '100%' }}
                    bodyStyle={{ padding: 16 }}
                  >
                    <Space direction="vertical" size={4} style={{ width: '100%' }}>
                      <Text strong>{m.name}</Text>
                      <Text type="secondary" style={{ fontSize: 12, minHeight: 32, display: 'block' }}>
                        {m.desc}
                      </Text>
                      {m.countKey && count !== undefined && (
                        <Tag color={count === null ? 'default' : 'blue'}>
                          {count === null ? '—（加载失败，点刷新重试）' : `${count} 个`}
                        </Tag>
                      )}
                    </Space>
                  </Card>
                </Col>
              );
            })}
          </Row>
        </>
      )}
    </div>
  );
};

export default Overview;

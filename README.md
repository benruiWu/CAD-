# CAD definition in KARE cohort

在昆山数据库中结合不同来源和类型的诊断信息对急性心梗进行精准定义。

## Oracle 实现思路

1. 在患者维表 (`dim_patient`) 中获取基础人口学特征。
2. 将 CAD 相关诊断（ICD-10 I20-I25 段）从门急诊与住院诊断事实表 (`fact_diagnosis`) 中抽取，并对急性心梗编码（I21）标记为强证据。
3. 结合介入及手术操作表 (`fact_procedure`)，捕获 PCI、CABG 等冠脉重建操作，PCI 作为金标准证据。
4. 提取心电图结果 (`fact_ecg_result`)，定位 ST 段改变、病理性 Q 波等强证据。
5. 从用药表 (`fact_medication`) 中识别长期 CAD 相关药物（硝酸甘油、阿司匹林、他汀等）作为中等证据。
6. 采集就诊症状表 (`fact_encounter_symptom`)，定位胸痛、胸闷、呼吸困难等临床表现。
7. 使用化验结果表 (`fact_lab_result`) 判断心肌损伤标志物是否异常升高，作为强证据。
8. 读取影像学报告表 (`fact_imaging_report`)，确认冠状动脉造影、心脏 CT 等结构证据，冠脉造影定义为金标准证据。
9. 汇总慢病史表 (`fact_chronic_condition`)，记录高血压、糖尿病、血脂异常等弱证据。
10. 综合所有来源，根据证据类别（金标准、强、中、弱）赋予分值并计算患者级别的综合评分与证据分层，输出 CAD 分类结果（确诊、高概率、可能、待复核）。

## SQL 脚本

详见 [`sql/cad_definition_oracle.sql`](sql/cad_definition_oracle.sql)，脚本使用公共表表达式依次整合上述证据来源，并给出最终的 CAD 分类结果。

> 所有表名及代码仅作为模板示例，可根据实际库表结构和编码体系进行调整。

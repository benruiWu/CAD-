# CAD definition in KARE cohort

在昆山数据库中结合不同来源和类型的诊断信息对急性心梗进行精准定义。

## Oracle 实现思路

1. 在患者维表 (`dim_patient`) 中获取基础人口学特征。
2. 将 CAD 相关诊断（ICD-10 I20-I25 段）从门急诊与住院诊断事实表 (`fact_diagnosis`) 中抽取。
3. 结合介入及手术操作表 (`fact_procedure`)，捕获 PCI、CABG 等冠脉重建操作。
4. 从用药表 (`fact_medication`) 中识别长期 CAD 相关药物（硝酸甘油、阿司匹林、他汀等）。
5. 使用化验结果表 (`fact_lab_result`) 判断心肌损伤标志物是否异常升高。
6. 读取影像学报告表 (`fact_imaging_report`)，确认冠状动脉造影、心脏 CT 等结构证据。
7. 综合所有来源，根据证据类型赋予不同权重并计算患者级别的综合评分。
8. 依据评分与证据覆盖范围输出 CAD 分层结果（确诊、疑似、需人工复核）。

## SQL 脚本

详见 [`sql/cad_definition_oracle.sql`](sql/cad_definition_oracle.sql)，脚本使用公共表表达式依次整合上述证据来源，并给出最终的 CAD 分类结果。

> 所有表名及代码仅作为模板示例，可根据实际库表结构和编码体系进行调整。

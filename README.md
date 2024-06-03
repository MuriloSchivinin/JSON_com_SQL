# JSON COM SQL SERVER :clipboard:
Nas últimas versões do SQL SERVER, foi disponibilizada a leitura de textos no formado JSON para trabalharmos de uma forma mais prática com a integração de dados, na grande maioria, integrações entre sistemas de diferentes origens.
Então, com base no breve conhecimento que adquiri trabalhando neste formado o banco de dados, resolvi criar uma documentação simples e direta que possibilita trabalharmos com esses textos no SQL SERVER.
<br>
<br>
## Criação de Tabelas Temporárias :page_with_curl:
Foram criadas duas tabelas quase que idênticas, onde a #tmp_times_brasileiros vai simular a base de dados de onde será feita a "Extração", enquanto a #tmp_times_brasileiros_json será a tabela onde os dados serão carregados após o 'ETL'.
Já, a terceira tabela " #tmp_columns " será a tabela utilizada no processo de "Transformação" dos dados, quanto utilizamos o PIVOT como método de leitura. 

## FOR JSON PATH 
Um detalhe legal à ser mencionado é o parâmetro que usei na hora de gerar o JSON em cima da tabela #tmp_times_brasileiros, que é o INCLUDE_NULL_VALUES, uma vez que usado, qualquer linha que constar valores nulos na tabela, a coluna será contemplada no texto JSON e o parâmetro em si será considerado como nulo.
Observe o estado inicial da tabela, onde a coluna titulos_mundiais to time Palmeiras, o campo está null
![image](https://github.com/MuriloSchivinin/Lendo-JSON-com-SQL/assets/71531288/7d12754b-6f36-4c29-85b4-30aff6bc0f7b)

Utilizando o INCLUDE_NULL_VALUES, temos o seguinte retorno do JSON:
```
SELECT *
FROM #tmp_times_brasileiros
FOR JSON PATH, INCLUDE_NULL_VALUES, ROOT('times')
```
![image](https://github.com/MuriloSchivinin/Lendo-JSON-com-SQL/assets/71531288/dcead804-d0e6-401e-b194-9630f1f37307)

Em caso de não utilizar este parâmetro, vocês poderiam observar que ao gerar o dicionário do time Palmeiras, o parâmetro não existirá no texto JSON:
```
SELECT *
FROM #tmp_times_brasileiros
FOR JSON PATH, ROOT('times')
```
![image](https://github.com/MuriloSchivinin/Lendo-JSON-com-SQL/assets/71531288/aa4644c9-9049-4ee9-b38d-a2d19139da35)
<br>
<br>
## Tipos de Leitura Definidos :capital_abcd:
Vocês poderão observar que no código, foi adicionado um IF para a varíavel @v_tipo_leitura, uma vez que ela for igual a WITH, a leitura do texto será com WITH, equanto quando a variável for PIVOT, faremos um PIVOT na tabela, tornando o processo mais dinâmico.
- WITH:
```
@v_tipo_leitura = 'WITH'
BEGIN
      ...

			INSERT INTO #tmp_times_brasileiros_json
			SELECT nome_time,
				   data_criacao,
				   estado_time,
				   CASE
					   WHEN titulos_mundiais IS NULL THEN
						   nome_time + ' não tem Mundial'
					   ELSE
						   titulos_mundiais
				   END AS titulos_mundiais,
				   titulos_brasileiros,
				   presidente_atual,
				   @v_tipo_leitura
			FROM
				OPENJSON(@v_time)
				WITH
				(
					nome_time			      VARCHAR(15) '$.nome_time',
					data_criacao		    DATETIME	  '$.data_criacao',
					estado_time			    CHAR(2)		  '$.estado_time',
					titulos_mundiais	  VARCHAR(30) '$.titulos_mundiais',
					titulos_brasileiros INT			    '$.titulos_brasileiros',
					presidente_atual	  VARCHAR(30) '$.titulos_brasileiros'
				)
END
```
- PIVOT:
```
@v_tipo_leitura = 'PIVOT'
BEGIN
      ...

			TRUNCATE TABLE #tmp_columns

			SELECT @v_time = Value
			FROM OPENJSON(@v_json, '$.times')
			WHERE [Key] = @v_count

			INSERT INTO #tmp_columns
			SELECT [Key], Value
			FROM OPENJSON(@v_time)	

			SELECT @v_columns = STRING_AGG(QUOTENAME(chave), ',')
			FROM #tmp_columns

			SET @v_qry = '
			INSERT INTO #tmp_times_brasileiros_json
			SELECT ' + @v_columns + ', [tipo_insert] = ''' + @v_tipo_leitura +  '''  
			FROM #tmp_columns
			PIVOT (MAX(valor) FOR chave IN (' + @v_columns + ')) AS B
			'
			EXEC(@v_qry)
END
```

# Considerações Finais ✅
Ambas as formas de leitura são corretas e de bom uso, mas eu quis apresentar um modelo talvez não muito usado que é o PIVOT, pois dependendo do tamanho do texto JSON, seria inviável ficarmo atribuindo as colunas no WITH.
Com o uso do PIVOT, conseguimos de uma forma dinâmica, conhecer as chaves e valores que estão vindo e a partir daí definirmos o que fazer com nosso desenvolvimento. 

Abaixo, o retorno do JSON através de ambos os modelos de leitura:

![screenshot_05](https://github.com/MuriloSchivinin/Lendo-JSON-com-SQL/assets/71531288/f1854d49-cdf7-4165-b0a1-1639ad888829)

![image](https://github.com/MuriloSchivinin/Lendo-JSON-com-SQL/assets/71531288/26b2be93-9970-4b79-9918-827698415e2c)


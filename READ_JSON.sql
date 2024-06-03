	BEGIN -- Criação das tabelas temporárias e inserção
		IF OBJECT_ID('tempdb.dbo.#tmp_times_brasileiros') IS NOT NULL
		BEGIN
			DROP TABLE #tmp_times_brasileiros
		END

		IF OBJECT_ID('tempdb.dbo.#tmp_times_brasileiros_json') IS NOT NULL
		BEGIN
			DROP TABLE #tmp_times_brasileiros_json
		END

		IF OBJECT_ID('tempdb.dbo.#tmp_columns') IS NOT NULL
		BEGIN
			DROP TABLE #tmp_columns
		END;


		CREATE TABLE #tmp_times_brasileiros
		(
			nome_time		VARCHAR(15) NOT NULL,
			data_criacao		DATETIME NOT NULL,
			estado_time		CHAR(2),
			titulos_mundiais	VARCHAR(30),
			titulos_brasileiros 	INT,
			presidente_atual	VARCHAR(30)
		)

		CREATE TABLE #tmp_times_brasileiros_json
		(
			nome_time		VARCHAR(15) NOT NULL,
			data_criacao		DATETIME NOT NULL,
			estado_time		CHAR(2),
			titulos_mundiais	VARCHAR(30),
			titulos_brasileiros 	INT,
			presidente_atual	VARCHAR(30),
			tipo_leitura		CHAR(5)
		)

		CREATE TABLE #tmp_columns
		(
			chave			VARCHAR(50),
			valor			VARCHAR(MAX)
		);

		INSERT INTO #tmp_times_brasileiros
		(
			nome_time,
			data_criacao,
			estado_time,
			titulos_mundiais,
			titulos_brasileiros,
			presidente_atual
		)
		VALUES
		('Corinthians', '19100901', 'SP', 2   , 7, 'Augusto Melo'),
		('Flamengo'   , '18951115', 'RJ', 1   , 8, 'Rodolfo Landim'),
		('Grêmio'     , '19030915', 'RS', 1   , 1, 'Alberto Guerrao'),
		('Palmeiras'  , '19140826', 'SP', NULL, 12, 'Leila Pereira')
	END
	
	-- Variáveis para desenvolvimento
	DECLARE @v_json			VARCHAR(MAX),
		@v_count		INT,
		@v_countMax		INT,
		@v_tipo_leitura 	CHAR(5),
		@v_time			VARCHAR(MAX),
		@v_columns		VARCHAR(MAX),
		@v_qry			VARCHAR(MAX)

	SELECT @v_json =
	(
		SELECT *
		FROM #tmp_times_brasileiros
		FOR JSON PATH, INCLUDE_NULL_VALUES, ROOT('times')
	)

	SELECT @v_count = 0,
		   @v_countMax = COUNT([Key]),
		   @v_tipo_leitura = 'PIVOT'
	FROM OPENJSON(@v_json, '$.times')

	IF @v_tipo_leitura = 'WITH' --Necessário conecer os campos em que irá trabalhar.
	BEGIN
		WHILE @v_count < @v_countMax
		BEGIN

			SELECT @v_time = Value
			FROM OPENJSON(@v_json, '$.times')
			WHERE [Key] = @v_count

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
					nome_time		VARCHAR(15) '$.nome_time',
					data_criacao		DATETIME    '$.data_criacao',
					estado_time		CHAR(2)	    '$.estado_time',
					titulos_mundiais	VARCHAR(30) '$.titulos_mundiais',
					titulos_brasileiros 	INT	    '$.titulos_brasileiros',
					presidente_atual	VARCHAR(30) '$.titulos_brasileiros'
				)

			SET @v_count += 1
		END
	END
	ELSE IF @v_tipo_leitura = 'PIVOT' -- Trona mais dinâmico quando se trata de um JSON maior e não sabemos exatamente os campos
	BEGIN

		WHILE @v_count < @v_countMax
		BEGIN
			
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

			SET @v_count += 1
		END

	END

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
		   tipo_leitura
	FROM #tmp_times_brasileiros_json

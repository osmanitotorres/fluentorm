# Sample04 - Cadastro de clientes (VCL + FireDAC + MySQL)

Aplicacao com formulario que usa as principais partes do FluentORM contra um MySQL local.

| Recurso | Onde ver |
|---------|----------|
| Conexao FireDAC e localizacao automatica da `libmysql.dll` | `ConfigureVendorLib`, `Connect` |
| Criacao do banco e da tabela | botao **Criar banco/tabela** |
| Listagem com `TSQLBuilder`: filtro `LIKE` em grupo `(... OR ...)`, "somente ativos", `ORDER BY`, paginacao `LIMIT/OFFSET`, total com `ToSQLCount` | `LoadPage` |
| Leitura com `TRepository<T>.FindById` (inclui colunas `[ReadOnly]` preenchidas pelo banco) | botao **Editar** / duplo clique |
| `Insert` (o id gerado volta para a entidade), `Update`, `DeleteById` | botoes **Salvar** e **Excluir** |
| `Variant` para coluna anulavel (`data_nascimento`), `Currency`, `Boolean`, `TEXT` | `TClienteDTO` |
| Transacao com varios `Insert` (`TSQLTransaction.ExecuteInTransaction`) | botao **Gerar 25 clientes** |
| Log de todo SQL executado + parametros (decorator de `ISQLExecutor`) e do SQL gerado pelo builder (`OnSQLGenerated`) | aba **Log de SQL**, `TLoggingExecutor` |

## Como rodar

1. Compile em **Win64** (o MySQL Server instala a `libmysql.dll` de 64 bits). O `build.bat` da raiz ja gera `Build\Win64\Sample04.exe`.
2. Abra o programa. Os dados de acesso ja vem preenchidos (`localhost:3306`, banco `fluentorm_demo`).
3. Na primeira vez clique em **Criar banco/tabela** (ou rode `script-mysql.sql`). Depois, **Gerar 25 clientes** para ter dados para paginar.

## libmysql.dll

O programa procura, nesta ordem:

1. `libmysql.dll` na pasta do executavel;
2. `C:\Program Files\MySQL\MySQL Server x.y\lib\libmysql.dll` (a pasta `bin` da mesma instalacao e adicionada a busca de DLLs, por causa das dependencias OpenSSL).

Se aparecer "Cannot load vendor library", copie a `libmysql.dll` e as DLLs `libssl*`/`libcrypto*` da pasta `bin` do MySQL Server para a pasta do executavel.

## Permissoes

O botao **Criar banco/tabela** executa `CREATE DATABASE`. Se o usuario nao tiver esse privilegio, crie o banco como `root` e conceda acesso:

```sql
CREATE DATABASE fluentorm_demo CHARACTER SET utf8mb4;
GRANT ALL PRIVILEGES ON fluentorm_demo.* TO 'osmanito'@'localhost';
```

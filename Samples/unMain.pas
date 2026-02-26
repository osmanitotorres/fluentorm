unit unMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, uFluentORM, System.Rtti, System.TypInfo,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef,
  FireDAC.UI.Intf,
  FireDAC.VCLUI.Wait,
  FireDAC.DApt,
  FireDAC.Stan.Async,
  FireDAC.Stan.Pool,
  uFluentORM.Attributes,
  uFluentORM.Repository,
  uFluentORM.Executor,
  uFluentORM.Executor.FireDAC,
  uFluentORM.ConnectionPool.FireDAC;

 type
  [Table('usuario')]
  TUsuarioDTO = class
  private
    FId: Integer;
    FEmail: string;
    FCpf: string;
    FSenha: string;
    FNickname: string;
  public
    [Key(True)]
    [Column('id')]
    property Id: Integer read FId write FId;

    [Column('email')]
    property Email: string read FEmail write FEmail;

    [Column('cpf')]
    property Cpf: string read FCpf write FCpf;

    [Column('senha')]
    property Senha: string read FSenha write FSenha;

    [Column('nickname')]
    property Nickname: string read FNickname write FNickname;

  end;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    BitBtn3: TBitBtn;
    BitBtn4: TBitBtn;
    BitBtn5: TBitBtn;
    BitBtn6: TBitBtn;
    BitBtn7: TBitBtn;
    BitBtn8: TBitBtn;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn3Click(Sender: TObject);
    procedure ExemploPersistenciaMySQL;
    procedure BitBtn4Click(Sender: TObject);
    procedure BitBtn5Click(Sender: TObject);
    procedure BitBtn6Click(Sender: TObject);
    procedure BitBtn7Click(Sender: TObject);
    procedure BitBtn8Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.BitBtn1Click(Sender: TObject);
var
  SQL: TSQLBuilder;
  QuerySQL: string;
  CountSQL: string;
begin
  SQL := TSQLBuilder.Create;
  try
    // Configura o tipo de banco
    SQL.SetDatabaseType(dbMSSQL); // AGORA FUNCIONA

    // Exemplo 1: Consulta simples
    QuerySQL := SQL.Select
                   .Fields(['id', 'nome', 'email'])
                   .From('pessoas')
                   .Where('ativo', True)
                   .OrderByAsc('nome')
                   .ToSQL;

    Memo1.Lines.Add('Consulta 1:');
    Memo1.Lines.Add(QuerySQL);
    Memo1.Lines.Add('');

    // Exemplo 2: Consulta com múltiplas condições
    SQL.Clear; // Limpa para nova consulta
    QuerySQL := SQL.Select
                   .All
                   .From('clientes')
                   .Where('cidade', 'São Paulo')
                   .AndWhere('idade', 18, opGreaterOrEqual)
                   .AndWhere('idcidade',1, opGreaterOrEqual)
                   .OrWhere('uf', 'SP')
                   .OrderByDesc('nome')
                   .Limit(100)
                   .ToSQL;

    Memo1.Lines.Add('Consulta 2:');
    Memo1.Lines.Add(QuerySQL);
    Memo1.Lines.Add('');

    // Exemplo 3: Paginação - AGORA FUNCIONA (Paginate)
    SQL.Clear;
    QuerySQL := SQL.Select
                   .All
                   .From('produtos')
                   .Where('categoria_id', 5)
                   .OrderByDesc('nome')
                   .Paginate(2, 20) // Página 2, 20 itens
                   .ToSQL;

    Memo1.Lines.Add('Consulta 3 (paginada):');
    Memo1.Lines.Add(QuerySQL);

    // Exemplo 4: COUNT - AGORA FUNCIONA (ToSQLCount)
    SQL.Clear;
    CountSQL := SQL.Select
                   .Fields(['id', 'nome'])
                   .From('clientes')
                   .Where('ativo', True)
                   .ToSQLCount;

    Memo1.Lines.Add('');
    Memo1.Lines.Add('SQL para COUNT:');
    Memo1.Lines.Add(CountSQL);

  finally
    SQL.Free;
  end;

end;

procedure TForm1.BitBtn2Click(Sender: TObject);
var
  SQL: TSQLBuilder;
  QuerySQL: string;
  DataInicio, DataFim: TDate;
begin
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMySQL);

    DataInicio := EncodeDate(2024, 1, 1);
    DataFim := EncodeDate(2024, 12, 31);

    QuerySQL := SQL.Select
                   .Fields([
                     'v.id as vendedor_id',
                     'v.nome as vendedor',
                     'c.id as cliente_id',
                     'c.nome as cliente',
                     'c.cidade',
                     'c.uf',
                     'p.id as produto_id',
                     'p.nome as produto',
                     'p.categoria',
                     'SUM(iv.quantidade) as total_vendido',
                     'SUM(iv.quantidade * iv.preco_unitario) as valor_total',
                     'COUNT(DISTINCT pe.id) as num_pedidos'
                   ])
                   .From('vendedores v')
                   .Join('pedidos pe', 'pe.vendedor_id = v.id')
                   .Join('clientes c', 'c.id = pe.cliente_id')
                   .Join('itens_venda iv', 'iv.pedido_id = pe.id')
                   .Join('produtos p', 'p.id = iv.produto_id')
                   .Where('pe.data_pedido', DataInicio, opGreaterOrEqual)
                   .AndWhere('pe.data_pedido', DataFim, opLessOrEqual)
                   .AndWhere('pe.status', 'CONCLUIDO')
                   .AndWhere('v.ativo', True)
                   .GroupBy([
                     'v.id',
                     'v.nome',
                     'c.id',
                     'c.nome',
                     'c.cidade',
                     'c.uf',
                     'p.id',
                     'p.nome',
                     'p.categoria'
                   ])
                   .Having('valor_total', 1000, opGreaterOrEqual)
                   .OrderByDesc('v.nome, valor_total DESC')
                   .ToFormattedSQL(4);

    Memo1.Lines.Add('=== RELATÓRIO CORRIGIDO (SEM OPERADORES DUPLICADOS) ===');
    Memo1.Lines.Add(QuerySQL);
    // Resultado esperado:
    // WHERE pe.data_pedido >= 45292 AND pe.data_pedido <= 45657 ...
    // HAVING valor_total >= 1000 ...

  finally
    SQL.Free;
  end;
end;

procedure TForm1.BitBtn3Click(Sender: TObject);
var
  SQL: TSQLBuilder;
  QuerySQL: string;
  DataInicio, DataFim: TDate;
begin

  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMySQL);

    SQL.UseNamedParams := True;
    SQL.StrictMode := True;

    QuerySQL := SQL.Select
                   .All
                   .From('pedidos')
                   .WhereIn('status', ['ABERTO', 'PAGO', 'ENVIADO'])
                   .AndWhereNotNull('cliente_id')
                   .ToFormattedSQL(4);
    Memo1.Lines.Add(QuerySQL);
  finally
    SQL.Free;
  end;

end;



procedure TForm1.BitBtn4Click(Sender: TObject);
begin
  ExemploPersistenciaMySQL;
end;

procedure TForm1.BitBtn5Click(Sender: TObject);
var
  Conn: TFDConnection;
  Exec: ISQLExecutor;
  Repo: TRepository<TUsuarioDTO>;
  U1, U2: TUsuarioDTO;
begin
  Conn := TFDConnection.Create(nil);
  try
    Conn.LoginPrompt := False;
    Conn.Params.Clear;
    Conn.Params.Add('DriverID=MySQL');
    Conn.Params.Add('Server=localhost');
    Conn.Params.Add('Port=3306');
    Conn.Params.Add('Database=chat_database');
    Conn.Params.Add('User_Name=root');
    Conn.Params.Add('Password=root');
    Conn.Connected := True;

    Exec := TFireDACSQLExecutor.Create(Conn) as ISQLExecutor;
    Repo := TRepository<TUsuarioDTO>.Create(Exec);
    U1 := TUsuarioDTO.Create;
    U2 := TUsuarioDTO.Create;

    try
      TSQLTransaction.ExecuteInTransaction(Exec,
        procedure
        begin
          U1.Email := 'ricardo@gmail.com';
          U1.Cpf := '888.456.789-44';
          U1.Senha := '1239300';
          U1.Nickname:='Ricardo Marques';
          Repo.Insert(U1);

          U2.Email := 'fernando@gmail.com';
          U2.Cpf := '111.257.000-22';
          U2.Senha := '#$ghb';
          U2.Nickname:='Fernando Marques';
          Repo.Insert(U2);
        end
      );
    finally
      U1.Free;
      U2.Free;
      Repo.Free;
    end;
  finally
    Conn.Free;
  end;
end;


procedure TForm1.BitBtn6Click(Sender: TObject);
var
  Params: TStringList;
  PoolFactory: IFireDACConnectionFactory;
  PoolOptions: TFireDACPoolOptions;
  Repo: TRepository<TUsuarioDTO>;
  Exec: ISQLExecutor;
begin
  Params := TStringList.Create;
  try
    Params.Values['DriverID'] := 'MySQL';
    Params.Values['Server'] := 'localhost';
    Params.Values['Port'] := '3306';
    Params.Values['Database'] := 'chat_database';
    Params.Values['User_Name'] := 'root';
    Params.Values['Password'] := 'root';

    PoolOptions := TFireDACPoolOptions.Default;
    PoolFactory := TFireDACPooledConnectionFactory.Create(Params, PoolOptions);
    Exec := TFireDACSQLExecutor.CreateFromFactory(PoolFactory);

    Repo := TRepository<TUsuarioDTO>.Create(Exec);
    try
      Repo.DeleteById(9); // remove usuario com id = 9
      Repo.DeleteById(10); // remove usuario com id = 10

    finally
      Repo.Free;
    end;
  finally
    Params.Free;
  end;

end;

procedure TForm1.BitBtn7Click(Sender: TObject);
var
  CountSQL: string;
  SQL: TSQLBuilder;
begin

  SQL:=TSQLBuilder.Create;

  try

    try
      CountSQL := SQL.Select
               .From('clientes c')
               .LeftJoin('debitos b','b.idCliente=c.id_cliente')
               .Where('ativo', True)
               .AndWhere('valor>=',1000)
               .ToFormattedSQLCount;
    finally
      Memo1.Lines.Text:=CountSQL;
    end;
  finally
    SQL.Free;
  end;


end;

procedure TForm1.BitBtn8Click(Sender: TObject);
var
  Contexto: TRttiContext;
  Tipo: TRttiType;
  Propriedade: TRttiProperty;
  Metodo: TRttiMethod;
  Objeto: TObject;
begin
Objeto := TStringList.Create;
  try
    // Obtém informações de tipo em tempo de execução
    Contexto := TRttiContext.Create;
    try
      Tipo := Contexto.GetType(Objeto.ClassInfo);

      // Descobrindo propriedades
      for Propriedade in Tipo.GetProperties do
        Memo1.lines.Add('Propriedade: ' + Propriedade.Name +
                   ' - Tipo: ' + Propriedade.PropertyType.Name);

      // Descobrindo métodos
      for Metodo in Tipo.GetMethods do
        Memo1.lines.Add('Método: ' + Metodo.Name);

    finally
      Contexto.Free;
    end;
  finally
    Objeto.Free;
  end;
end;

procedure TForm1.ExemploPersistenciaMySQL;
var
  Conn: TFDConnection;
  Repo: TRepository<TUsuarioDTO>;
  Exec: ISQLExecutor;
begin
  Conn := TFDConnection.Create(nil);
  try
    Conn.LoginPrompt := False;
    Conn.Params.Clear;
    Conn.Params.Add('DriverID=MySQL');
    Conn.Params.Add('Server=localhost');
    Conn.Params.Add('Port=3306');
    Conn.Params.Add('Database=chat_database');
    Conn.Params.Add('User_Name=root');
    Conn.Params.Add('Password=root');
    Conn.Connected := True;

    Exec := TFireDACSQLExecutor.Create(Conn);
    Repo := TRepository<TUsuarioDTO>.Create(Exec);
    try
      Repo.DeleteById(6); // remove usuario com id = 1
    finally
      Repo.Free;
    end;
  finally
    Conn.Free;
  end;
end;



end.



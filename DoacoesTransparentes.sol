// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Histórico público de doações e gastos declarados por campanha.
/// @dev Valores em reais inteiros. Os pagamentos ocorrem fora do contrato.
contract DoacoesTransparentes {
    struct Campanha {
        uint id;
        string nome;
        uint meta;
        uint totalArrecadado;
        uint totalGasto;
        bool aberta;
        uint dataCriacao;
    }

    struct Doacao {
        address doador;
        uint valor;
        uint data;
    }

    struct Gasto {
        uint valor;
        string descricao;
        address destinatario;
        string referenciaComprovante; // Exemplo: NF-12345
        uint data;
    }

    address public ong;
    uint public totalCampanhas;

    mapping(uint => Campanha) private campanhas;
    mapping(uint => Doacao[]) private doacoes;
    mapping(uint => Gasto[]) private gastos;

    event CampanhaCriada(uint indexed id, string nome, uint meta);
    event DoacaoRegistrada(uint indexed idCampanha, address indexed doador, uint valor);
    event GastoRegistrado(uint indexed idCampanha, uint valor, string descricao, address destinatario);
    event CampanhaEncerrada(uint indexed id);

    modifier somenteONG() {
        require(msg.sender == ong, "Apenas a ONG pode executar esta funcao");
        _;
    }

    modifier campanhaExiste(uint _id) {
        require(_id > 0 && _id <= totalCampanhas, "Campanha nao existe");
        _;
    }

    constructor() {
        // A carteira que implanta o contrato fica responsável pelas campanhas.
        ong = msg.sender;
    }

    function criarCampanha(string memory _nome, uint _meta) public somenteONG {
        require(bytes(_nome).length > 0, "Nome obrigatorio");
        require(_meta > 0, "Meta deve ser maior que zero");

        totalCampanhas++;
        campanhas[totalCampanhas] = Campanha({
            id: totalCampanhas,
            nome: _nome,
            meta: _meta,
            totalArrecadado: 0,
            totalGasto: 0,
            aberta: true,
            dataCriacao: block.timestamp
        });

        emit CampanhaCriada(totalCampanhas, _nome, _meta);
    }

    function doar(uint _idCampanha, uint _valor) public campanhaExiste(_idCampanha) {
        Campanha storage c = campanhas[_idCampanha];
        require(c.aberta, "Campanha encerrada");
        require(_valor > 0, "Valor da doacao deve ser maior que zero");

        c.totalArrecadado += _valor;
        doacoes[_idCampanha].push(Doacao(msg.sender, _valor, block.timestamp));

        emit DoacaoRegistrada(_idCampanha, msg.sender, _valor);
    }

    function registrarGasto(
        uint _idCampanha,
        uint _valor,
        string memory _descricao,
        address _destinatario,
        string memory _referenciaComprovante
    ) public somenteONG campanhaExiste(_idCampanha) {
        Campanha storage c = campanhas[_idCampanha];
        require(_valor > 0, "Valor deve ser maior que zero");
        require(_valor <= c.totalArrecadado - c.totalGasto, "Saldo insuficiente na campanha");
        require(bytes(_descricao).length > 0, "Descricao obrigatoria");
        require(_destinatario != address(0), "Destinatario invalido");
        require(bytes(_referenciaComprovante).length > 0, "Comprovante obrigatorio");

        c.totalGasto += _valor;
        gastos[_idCampanha].push(Gasto(_valor, _descricao, _destinatario, _referenciaComprovante, block.timestamp));

        emit GastoRegistrado(_idCampanha, _valor, _descricao, _destinatario);
    }

    /// @notice A ONG pode registrar despesas mesmo depois do encerramento.
    function encerrarCampanha(uint _idCampanha) public somenteONG campanhaExiste(_idCampanha) {
        require(campanhas[_idCampanha].aberta, "Campanha ja esta encerrada");
        campanhas[_idCampanha].aberta = false;
        emit CampanhaEncerrada(_idCampanha);
    }

    function consultarCampanha(uint _idCampanha) public view campanhaExiste(_idCampanha) returns (Campanha memory) {
        return campanhas[_idCampanha];
    }

    function saldoCampanha(uint _idCampanha) public view campanhaExiste(_idCampanha) returns (uint) {
        Campanha storage c = campanhas[_idCampanha];
        return c.totalArrecadado - c.totalGasto;
    }

    function listarDoacoes(uint _idCampanha) public view campanhaExiste(_idCampanha) returns (Doacao[] memory) {
        return doacoes[_idCampanha];
    }

    function listarGastos(uint _idCampanha) public view campanhaExiste(_idCampanha) returns (Gasto[] memory) {
        return gastos[_idCampanha];
    }

    function metaAtingida(uint _idCampanha) public view campanhaExiste(_idCampanha) returns (bool) {
        return campanhas[_idCampanha].totalArrecadado >= campanhas[_idCampanha].meta;
    }
}

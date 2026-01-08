# Moodle 5.1 Docker - Instalação Automática

Este script automatiza completamente a instalação do Moodle 5.1 com Docker.

## Requisitos

- Docker instalado
- Docker Compose instalado
- Ficheiros do Moodle 5.1 (descarregados do site oficial)

## Instalação em 3 Passos

### 1. Extrair ficheiros do Moodle

```bash
# Crie a pasta moodle e extraia os ficheiros do Moodle 5.1 para dentro dela
mkdir moodle
cd moodle
# Extraia aqui os ficheiros do Moodle...
cd ..
```

**Estrutura esperada:**
```
seu-projeto/
├── setup-moodle.sh    (o script de instalação)
└── moodle/            (ficheiros do Moodle 5.1)
    ├── admin/
    ├── lib/
    ├── public/
    └── ...
```

### 2. Executar o script de configuração

```bash
chmod +x setup-moodle.sh
./setup-moodle.sh
```

O script irá:
- ✅ Verificar os pré-requisitos
- ✅ Criar o `docker-compose.yml`
- ✅ Criar os ficheiros de configuração
- ✅ Criar scripts auxiliares
- ✅ Perguntar se deseja personalizar as configurações (ou usar padrões)

### 3. Iniciar e instalar

```bash
# Iniciar os containers
./start.sh

# Aguardar 2-3 minutos (primeira vez instala extensões PHP)

# Instalar o Moodle
./install-moodle.sh
```

**Pronto! 🎉**

Acesse: http://localhost:8080
- **Utilizador:** admin
- **Palavra-passe:** Admin123!

## Configurações Padrão

Se não personalizar, o script usa:

| Configuração | Valor Padrão |
|-------------|--------------|
| URL do Site | http://localhost:8080 |
| Base de Dados | moodle |
| Utilizador BD | moodle |
| Password BD | moodle |
| Utilizador Admin | admin |
| Password Admin | Admin123! |
| Email Admin | admin@example.com |

## Scripts Auxiliares Criados

Após executar `setup-moodle.sh`, terá estes scripts:

| Script | Função |
|--------|--------|
| `./start.sh` | Inicia os containers |
| `./stop.sh` | Para os containers |
| `./logs.sh` | Visualiza logs em tempo real |
| `./install-moodle.sh` | Instala o Moodle automaticamente |
| `./reset.sh` | Apaga TUDO e recomeça do zero ⚠️ |

## Comandos Úteis

```bash
# Ver estado dos containers
docker compose ps

# Ver logs
./logs.sh
# ou
docker compose logs -f moodle

# Reiniciar
docker compose restart

# Aceder ao container do Moodle
docker exec -it moodle_app bash

# Aceder à base de dados
docker exec -it moodle_db mysql -u moodle -pmoodle moodle

# Limpar caches do Moodle
docker exec -it moodle_app php /var/www/moodle/admin/cli/purge_caches.php
```

## Personalização Durante a Instalação

Quando executar `./setup-moodle.sh`, pode escolher personalizar:

```
Do you want to customize the installation settings? (y/n)
```

Se responder **y**, pode definir:
- Nome da base de dados
- Utilizador e password da BD
- URL do site
- Credenciais de administrador
- Nome do site

## Resolução de Problemas

### Erro: "Moodle directory not found"
**Solução:** Certifique-se que extraiu os ficheiros do Moodle para `./moodle/`

### Erro: "public directory not found"
**Solução:** Este script é para Moodle 5.1+. Verifique que tem a versão correta.

### Containers não iniciam
```bash
# Verificar logs
./logs.sh

# Reiniciar
./stop.sh
./start.sh
```

### Não consigo criar cursos ou fazer upload de ficheiros
**Solução:** Execute a instalação:
```bash
./install-moodle.sh
```

### Esqueci a password de administrador
**Solução:** Redefina via CLI:
```bash
docker exec -it moodle_app php /var/www/moodle/admin/cli/reset_password.php
```

### Quero recomeçar do zero
```bash
./reset.sh
./start.sh
./install-moodle.sh
```

## Estrutura de Ficheiros Criada

Após executar o script de configuração:

```
seu-projeto/
├── docker-compose.yml        # Configuração Docker
├── .env                      # Variáveis de ambiente (passwords)
├── setup-moodle.sh          # Script de configuração inicial
├── start.sh                 # Iniciar containers
├── stop.sh                  # Parar containers  
├── logs.sh                  # Ver logs
├── install-moodle.sh        # Instalar Moodle
├── reset.sh                 # Reset completo
├── README.md                # Documentação gerada
└── moodle/                  # Ficheiros do Moodle
    ├── config.php           # Configuração principal (criado)
    └── public/
        └── config.php       # Loader de config (criado)
```

## Para Produção

Para usar em produção:

1. **Altere as passwords:**
   ```bash
   nano .env
   ```

2. **Configure SSL/HTTPS:**
    - Obtenha certificado SSL
    - Configure no docker-compose.yml

3. **Atualize a URL:**
   ```bash
   nano moodle/config.php
   # Altere $CFG->wwwroot para https://seudominio.com
   ```

4. **Configure segurança:**
    - Adicione ao config.php:
   ```php
   $CFG->debug = 0;
   $CFG->debugdisplay = 0;
   $CFG->sessioncookiesecure = true;
   ```

5. **Configure backups automáticos** da base de dados e moodledata

## Suporte

- Documentação Moodle: https://docs.moodle.org
- Fóruns Moodle: https://moodle.org/forums

## O Que o Script Faz Automaticamente

1. ✅ Verifica se Docker está instalado
2. ✅ Verifica se os ficheiros do Moodle existem
3. ✅ Cria `docker-compose.yml` otimizado
4. ✅ Cria ficheiro `.env` com passwords
5. ✅ Cria `moodle/config.php` com configurações corretas
6. ✅ Cria `moodle/public/config.php` (loader)
7. ✅ Cria scripts auxiliares (start, stop, logs, install, reset)
8. ✅ Cria README.md com documentação completa
9. ✅ Configura permissões corretas
10. ✅ Configura health checks
11. ✅ Configura redes Docker
12. ✅ Configura volumes persistentes

**Resultado:** Setup completo em menos de 5 minutos! 🚀
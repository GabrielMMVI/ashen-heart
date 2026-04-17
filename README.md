# Ashen Heart
- A game by Atom(TM)
### Arquivos para controle de versão do projeto Ashen Heart.
___
$ByAtom$
## Documentação | Componentes
- Para melhor organização do projeto, seguiremos normas de nomeação e organização de pastas para melhor conforto ao editar os arquivos dos projetos.
### Regras de formatação de arquivos:
- Todos os arquivos salvos devem seguir a regra de nomeação abaixo:
  - Arquivos.gd = scr\<NomeDoArquivo>
  - Arquivos.tscn = \<NomeDoArquivo>
  - Pastas criadas = \<pasta>
- Também vale a regra para a criação de nós e componentes dentro do Projeto Godot:
  - Todo nó deve ser nomeado com uma abreviação de seu componente e em seguida com o nome do nó, por exemplo:
      - CharacterBody2d do player = chbPLayer
      - Area da hitbox = aHitbox
      - Colisão da hitbox = colHitbox
      - Colisão do player = colPlayer
- Para sons e imagens não é necessário um prefixo, apenas nomeeie o que é o recurso.
### Regras para organização de pastas:
- O projeto tem várias pastas para cada recurso necessário no jogo:
  - Salvar Assets e recursos AUDIOVISUAIS:
    - Pasta: ass
  - Salvar Cenas de telas que não pertencem a entidades:
    - Pasta: scn
      - Sempre salve os scripts das cenas na pasta scripts
  - Salvar entidades de player, inimigos, projéteis:
    - Pasta: ent
      - Sempre salve os scripts das entidades na pasta scripts
___

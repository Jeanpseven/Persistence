# Persistence
coloca persistência no kali live

o quão insuportavel é colocar e configurar uma persistência no USB com o Kali Linux

vim trazer esse script para automatizar todo o processe de dividir o pendrive em partição,colocar persistência,configurar no fstab e blah blah blah

espero que te ajude

organização de cada processo realizado nesse script (ignore)

# 1. Verifica se o sistema é o Kali Linux
# 2. Detecta automaticamente o dispositivo USB conectado
# 3. Verifica se o dispositivo USB possui uma partição montada
# 4. Desmonta qualquer partição existente no dispositivo USB
# 5. Determina o tipo de partição mais recomendado para o pendrive
# 6. Cria uma partição para persistência
# 7. Formata a partição com o tipo apropriado
# 8. Monta a partição persistente
# 9. Configura o arquivo /etc/fstab para montar a partição persistente na inicialização
# 10. Verifica se o usuário deseja configurar o tamanho do cluster e tamanho do bloco
# 11. Função para configurar o tamanho do cluster e tamanho do bloco
# 12. Execução principal do script




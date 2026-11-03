// Shell text in the three app languages. The shell follows <html lang>.
// {n} is the record count, as the app shows it on the Home tab.
module.exports = {
  'pt-BR': {
    close: {
      title: 'Fechar o Saíra',
      unsaved: 'Você ainda não exportou os dados',
      unsavedDetail: 'O Saíra não salva a sessão. Se fechar agora, o mapeamento e as correções de {n} registros serão perdidos.',
      unsavedDetailNoCount: 'O Saíra não salva a sessão. Se fechar agora, o mapeamento e as correções serão perdidos.',
      goExport: 'Ir para Exportação', discard: 'Fechar sem exportar',
      message: 'Fechar o Saíra?',
      detail: 'Você exportou os arquivos nesta sessão. As alterações feitas depois da exportação não ficam salvas.',
      confirm: 'Fechar', cancel: 'Cancelar'
    },
    lifecycle: {
      runtime: 'Preparando o R…', packages: 'Carregando os pacotes do R…', ui: 'Abrindo a interface…',
      wait: 'Isto pode levar alguns segundos.',
      photoAlt: 'Saíra-pintor pousada num talo verde', commonName: 'saíra-pintor', photo: 'Foto',
      crashTitle: 'O R do Saíra parou',
      crashText: 'O trabalho desta sessão foi perdido. Abra o Saíra de novo e carregue o arquivo outra vez.',
      startTitle: 'O Saíra não abriu',
      startText: 'O R parou antes de abrir a interface.',
      missingText: 'Faltam arquivos do R nesta instalação. Reinstale o Saíra.',
      reportText: 'Se o erro voltar, copie os detalhes e relate o problema.',
      reopen: 'Abrir de novo', retry: 'Tentar de novo', close: 'Fechar',
      issue: 'Relatar um problema no GitHub', log: 'Últimas linhas do R',
      copy: 'Copiar os detalhes', copied: 'Copiado',
      closing: 'Fechando o Saíra…'
    },
    download: { title: 'Salvar arquivo', type: 'Arquivo {ext}' }
  },
  en: {
    close: {
      title: 'Close Saíra',
      unsaved: 'You did not export the data',
      unsavedDetail: 'Saíra does not save the session. If you close now, you lose the mapping and the corrections of {n} records.',
      unsavedDetailNoCount: 'Saíra does not save the session. If you close now, you lose the mapping and the corrections.',
      goExport: 'Go to Export', discard: 'Close without export',
      message: 'Close Saíra?',
      detail: 'You exported the files in this session. Saíra does not save the changes after the export.',
      confirm: 'Close', cancel: 'Cancel'
    },
    lifecycle: {
      runtime: 'Preparing R…', packages: 'Loading the R packages…', ui: 'Opening the interface…',
      wait: 'This can take some seconds.',
      photoAlt: 'Tangara fastuosa on a green stem', commonName: '', photo: 'Photo',
      crashTitle: 'The R process of Saíra stopped',
      crashText: 'The work of this session is lost. Open Saíra again and load the file again.',
      startTitle: 'Saíra did not open',
      startText: 'R stopped before the interface opened.',
      missingText: 'Some R files of this installation are missing. Reinstall Saíra.',
      reportText: 'If the error occurs again, copy the details and report the problem.',
      reopen: 'Open again', retry: 'Try again', close: 'Close',
      issue: 'Report a problem on GitHub', log: 'Last lines from R',
      copy: 'Copy the details', copied: 'Copied',
      closing: 'Closing Saíra…'
    },
    download: { title: 'Save file', type: '{ext} file' }
  },
  es: {
    close: {
      title: 'Cerrar Saíra',
      unsaved: 'Todavía no exportó los datos',
      unsavedDetail: 'Saíra no guarda la sesión. Si cierra ahora, se pierden el mapeo y las correcciones de {n} registros.',
      unsavedDetailNoCount: 'Saíra no guarda la sesión. Si cierra ahora, se pierden el mapeo y las correcciones.',
      goExport: 'Ir a Exportación', discard: 'Cerrar sin exportar',
      message: '¿Cerrar Saíra?',
      detail: 'Exportó los archivos en esta sesión. Los cambios hechos después de la exportación no se guardan.',
      confirm: 'Cerrar', cancel: 'Cancelar'
    },
    lifecycle: {
      runtime: 'Preparando R…', packages: 'Cargando los paquetes de R…', ui: 'Abriendo la interfaz…',
      wait: 'Esto puede tardar unos segundos.',
      photoAlt: 'Tangara fastuosa posada en un tallo verde', commonName: '', photo: 'Foto',
      crashTitle: 'El proceso R de Saíra se detuvo',
      crashText: 'El trabajo de esta sesión se perdió. Abra Saíra otra vez y cargue el archivo de nuevo.',
      startTitle: 'Saíra no se abrió',
      startText: 'R se detuvo antes de abrir la interfaz.',
      missingText: 'Faltan archivos de R en esta instalación. Reinstale Saíra.',
      reportText: 'Si el error vuelve, copie los detalles e informe el problema.',
      reopen: 'Abrir de nuevo', retry: 'Reintentar', close: 'Cerrar',
      issue: 'Informar un problema en GitHub', log: 'Últimas líneas de R',
      copy: 'Copiar los detalles', copied: 'Copiado',
      closing: 'Cerrando Saíra…'
    },
    download: { title: 'Guardar archivo', type: 'Archivo {ext}' }
  }
};

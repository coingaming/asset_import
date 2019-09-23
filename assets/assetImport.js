export default {

  mounted() {
    const {importedScripts, importedStyles} = this.el.dataset;

    const headEl = document.getElementsByTagName("head")[0];
    importedStyles.split(" ").forEach(fileName => {
      if (headEl.querySelectorAll(`link[href="${fileName}"]`).length) {
        return;
      }
      const el = document.createElement("link");
      el.rel = "stylesheet";
      el.type = "text/css";
      el.href = fileName;
      headEl.appendChild(el)
    });

    const bodyEl = document.getElementsByTagName("body")[0];
    importedScripts.split(" ").forEach(fileName => {
      if (document.querySelectorAll(`script[src="${fileName}"]`).length) {
        return;
      }
      const el = document.createElement('script');;
      el.src = fileName;
      bodyEl.appendChild(el);
    });
  }

}

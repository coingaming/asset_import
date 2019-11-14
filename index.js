export default {

  mounted() {
    const { assetFiles } = this.el.dataset;
    const headEl = document.getElementsByTagName("head")[0];
    const bodyEl = document.getElementsByTagName("body")[0];

    assetFiles.split(" ").forEach(fileName => {
      if (fileName.substr(-4) === '.css') {
        if (headEl.querySelectorAll(`link[rel="stylesheet"][href="${fileName}"]`).length) {
          return;
        }
        const el = document.createElement("link");
        el.rel = "stylesheet";
        el.type = "text/css";
        el.href = fileName;
        headEl.appendChild(el)
      }
      else if (fileName.substr(-3) === '.js') {
        if (document.querySelectorAll(`script[src="${fileName}"]`).length) {
          return;
        }
        const el = document.createElement('script');;
        el.src = fileName;
        bodyEl.appendChild(el);
      }
    });
  }

}

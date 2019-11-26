const AssetImport = {

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

};

const AssetHook = {

  mounted() {
    const { assets, hook } = this.el.dataset;
    const headEl = document.getElementsByTagName("head")[0];
    const bodyEl = document.getElementsByTagName("body")[0];

    this.el.loadingAssets = assets;

    const onload = () => {
      const index = this.el.loadingAssets.indexOf(item);
      if (index !== -1) {
        this.el.loadingAssets.splice(index, 1);
        if (!this.el.loadingAssets.length) {
          console.log("Loaded", this);
        }
      }
    };

    assets.split(" ").forEach(fileName => {
      if (fileName.substr(-4) === '.css') {
        if (headEl.querySelectorAll(`link[rel="stylesheet"][href="${fileName}"]`).length) {
          return;
        }
        const el = document.createElement("link");
        el.rel = "stylesheet";
        el.type = "text/css";
        el.href = fileName;
        el.onload = onload;
        headEl.appendChild(el)
      }
      else if (fileName.substr(-3) === '.js') {
        if (document.querySelectorAll(`script[src="${fileName}"]`).length) {
          return;
        }
        const el = document.createElement('script');;
        el.src = fileName;
        el.onload = onload;
        bodyEl.appendChild(el);
      }
    });
  }

};

export {AssetImport, AssetHook};
export default AssetImport;

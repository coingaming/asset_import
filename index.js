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

    const assetFiles = assets.split(" ");

    this.el.loadingAssets = assetFiles.slice(0);

    const onload = (fileName) => {
      const index = this.el.loadingAssets.indexOf(fileName);
      if (index !== -1) {
        this.el.loadingAssets.splice(index, 1);
        if (!this.el.loadingAssets.length) {
          const hookFunc = this.__view.liveSocket.hooks[hook].mounted
          if (hookFunc) {
            hookFunc.apply(this);
          }
        }
      }
    };

    assetFiles.forEach(fileName => {
      if (fileName.substr(-4) === '.css') {
        if (headEl.querySelectorAll(`link[rel="stylesheet"][href="${fileName}"]`).length) {
          onload(fileName);
          return;
        }
        const el = document.createElement("link");
        el.rel = "stylesheet";
        el.type = "text/css";
        el.href = fileName;
        el.onload = () => onload(fileName);
        headEl.appendChild(el)
      }
      else if (fileName.substr(-3) === '.js') {
        if (document.querySelectorAll(`script[src="${fileName}"]`).length) {
          onload(fileName);
          return;
        }
        const el = document.createElement('script');;
        el.src = fileName;
        el.onload = () => onload(fileName);
        bodyEl.appendChild(el);
      }
    });
  },

  updated() {
    const { hook } = this.el.dataset;
    const hookFunc = this.__view.liveSocket.hooks[hook].updated
    if (hookFunc) {
      hookFunc.apply(this);
    }
  },

  destroyed() {
    const { hook } = this.el.dataset;
    const hookFunc = this.__view.liveSocket.hooks[hook].destroyed
    if (hookFunc) {
      hookFunc.apply(this);
    }
  }

};

export {AssetImport, AssetHook};
export default AssetImport;

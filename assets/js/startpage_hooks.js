export const StartpageInput = {
  mounted() {
    this.el.focus();

    this._keyHandler = (e) => {
      const key = e.key;
      if (["ArrowUp", "ArrowDown", "Tab"].includes(key)) {
        e.preventDefault();
        this.pushEvent("keydown", { key });
      } else if (key === "Enter") {
        e.preventDefault();
        this.pushEvent("keydown", { key });
      } else if (key === "Escape") {
        e.preventDefault();
        this.pushEvent("keydown", { key });
      }
    };

    this._inputHandler = () => {
      this.pushEvent("query_changed", { query: this.el.value });
    };

    this.el.addEventListener("keydown", this._keyHandler);
    this.el.addEventListener("input", this._inputHandler);
  },

  updated() {
    // Restore focus and move cursor to end after LiveView patches the DOM
    const val = this.el.value;
    this.el.focus();
    this.el.setSelectionRange(val.length, val.length);
  },

  destroyed() {
    this.el.removeEventListener("keydown", this._keyHandler);
    this.el.removeEventListener("input", this._inputHandler);
  }
};

export const StartpageTooltip = {
  mounted() {
    this._enterHandler = (e) => {
      const url = this.el.dataset.tooltipUrl;
      if (url) {
        this.pushEvent("show_tooltip", { url, x: e.clientX, y: e.clientY });
      }
    };
    this._moveHandler = (e) => {
      const url = this.el.dataset.tooltipUrl;
      if (url) {
        this.pushEvent("show_tooltip", { url, x: e.clientX, y: e.clientY });
      }
    };
    this._leaveHandler = () => {
      this.pushEvent("hide_tooltip", {});
    };

    this.el.addEventListener("mouseenter", this._enterHandler);
    this.el.addEventListener("mousemove", this._moveHandler);
    this.el.addEventListener("mouseleave", this._leaveHandler);
  },

  destroyed() {
    this.el.removeEventListener("mouseenter", this._enterHandler);
    this.el.removeEventListener("mousemove", this._moveHandler);
    this.el.removeEventListener("mouseleave", this._leaveHandler);
  }
};

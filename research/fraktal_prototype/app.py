"""Fraktal Portföy Simülasyonu — Streamlit arayüzü.

    streamlit run app.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import streamlit as st

sys.path.insert(0, str(Path(__file__).resolve().parent))
from src.data import DEFAULT_ASSETS, get_price_series, daily_returns, data_source  # noqa: E402
from src.fractal import hurst_rs, market_regime  # noqa: E402
from src.montecarlo import simulate_portfolio  # noqa: E402
from src.sentiment import analyze_bulletin  # noqa: E402
from src.backtest import backtest  # noqa: E402
from src.optimize import max_sharpe  # noqa: E402

st.set_page_config(page_title="Fraktal Portföy Simülasyonu", page_icon="📈", layout="wide")


def main():
    st.title("📈 Fraktal Piyasa Analizi Destekli Portföy Simülasyonu")
    st.caption("Hurst (fraktal) + Monte Carlo + FinBERT/Gemini sentiment füzyonu")

    with st.sidebar:
        st.header("Portföy")
        assets = st.multiselect("Varlıklar", list(DEFAULT_ASSETS),
                                default=["THYAO", "GARAN", "ALTIN"])
        horizon = st.slider("Ufuk (gün)", 30, 504, 252, 30)
        n_sims = st.select_slider("Simülasyon sayısı", [1000, 2000, 5000, 10000], 5000)
        sentiment_weight = st.slider("Sentiment ağırlığı", 0.0, 1.0, 0.3, 0.05)

    if not assets:
        st.info("En az bir varlık seçin.")
        return

    src_txt = " · ".join(f"{a}: {data_source(a)}" for a in assets)
    st.caption(f"📡 Veri kaynağı — {src_txt}")

    weights = []
    cols = st.columns(len(assets))
    for c, a in zip(cols, assets):
        weights.append(c.number_input(f"{a} ağırlık", 0.0, 1.0, 1.0 / len(assets), 0.05))

    # Markowitz optimal ağırlıklar — istenirse manuel ağırlıkların yerine geçer
    with st.expander("⚖️ Markowitz optimizasyonu (maks. Sharpe)"):
        rf = st.slider("Risksiz oran (yıllık)", 0.0, 1.0, 0.45, 0.05,
                       help="TL mevduat ~%45; gerçek değer EVDS'ten alınabilir.")
        alloc = max_sharpe(assets, rf=rf)
        ocols = st.columns(len(assets) + 1)
        for c, a, w in zip(ocols, assets, alloc.weights):
            c.metric(f"{a} (opt.)", f"%{w*100:.1f}")
        ocols[-1].metric("Sharpe", f"{alloc.sharpe:.2f}",
                         f"getiri %{alloc.expected_return*100:.0f} / vol %{alloc.volatility*100:.0f}")
        if st.checkbox("Optimal ağırlıkları kullan"):
            weights = list(alloc.weights)

    st.subheader("📰 Bülten / Haber (sentiment için)")
    bulletin = st.text_area("Finansal bülten metni yapıştırın",
                            "Piyasalarda güçlü büyüme ve rekor kâr beklentisi olumlu hava yarattı.")
    sent = analyze_bulletin(bulletin)
    st.info(f"Sentiment: **{sent.label}** ({sent.score:+.2f}) · backend: `{sent.backend}`\n\n"
            f"Özet: {sent.summary}")

    if st.button("🎲 Monte Carlo Simülasyonu Çalıştır", type="primary"):
        # Fraktal analiz
        st.subheader("🔬 Fraktal Analiz (Hurst)")
        hcols = st.columns(len(assets))
        for c, a in zip(hcols, assets):
            h = hurst_rs(daily_returns(get_price_series(a, 504, 0)))
            c.metric(a, f"H={h:.2f}", market_regime(h))

        res = simulate_portfolio(assets, weights, horizon, n_sims,
                                 sentiment=sent.score, sentiment_weight=sentiment_weight)
        st.subheader("🎯 Simülasyon Sonuçları")
        m = st.columns(4)
        m[0].metric("Beklenen değer", f"{res.expected_value:,.0f} ₺")
        m[1].metric("VaR %95", f"{res.var_95:,.0f} ₺")
        m[2].metric("CVaR %95", f"{res.cvar_95:,.0f} ₺")
        m[3].metric("Zarar olasılığı", f"%{res.prob_loss*100:.1f}")

        # Fan chart
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(9, 4))
        for p in res.paths_sample:
            ax.plot(p, color="#38bdf8", alpha=0.15, lw=0.8)
        ax.set_title("Monte Carlo portföy yörüngeleri (örnek)")
        ax.set_xlabel("Adım"); ax.set_ylabel("Portföy değeri (₺)")
        st.pyplot(fig)
        st.caption(f"Persentiller: {res.percentiles}")

        # Tarihsel backtest (geçmiş performans)
        st.subheader("📊 Tarihsel Backtest (geçmiş 504 gün)")
        bt = backtest(assets, weights)
        b = st.columns(5)
        b[0].metric("Toplam getiri", f"%{bt.total_return*100:.1f}")
        b[1].metric("CAGR (yıllık)", f"%{bt.cagr*100:.1f}")
        b[2].metric("Volatilite", f"%{bt.volatility*100:.1f}")
        b[3].metric("Sharpe", f"{bt.sharpe:.2f}")
        b[4].metric("Maks. düşüş", f"%{bt.max_drawdown*100:.1f}")


if __name__ == "__main__":
    main()

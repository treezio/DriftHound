import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this.currentEnv = '';
    this.createChart(this.dataValue);

    this.boundHandleFilter = this.handleFilter.bind(this);
    document.addEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
  }

  handleFilter(event) {
    const env = event.detail.environment || '';
    if (env !== this.currentEnv) {
      this.currentEnv = env;
      this.updateChart(this.getDataForEnv(env));
    }
  }

  getDataForEnv(env) {
    if (!env || env === '') {
      return this.dataValue;
    }
    const envData = this.dataValue.by_environment[env];
    if (envData) {
      return {
        score: envData.score,
        breakdown: envData.breakdown
      };
    }
    return this.dataValue;
  }

  getScoreColor(score) {
    if (score >= 80) return "#22c55e"; // green
    if (score >= 50) return "#f59e0b"; // amber
    return "#ef4444"; // red
  }

  createChart(data) {
    const score = data.score;
    const breakdown = data.breakdown;

    this.chart = new Chart(this.canvasTarget, {
      type: "doughnut",
      data: {
        labels: ["Stable (7+ checks)", "Moderate (3-6 checks)", "Unstable (<3 checks)"],
        datasets: [{
          data: [breakdown.stable_7plus, breakdown.stable_3to6, breakdown.unstable],
          backgroundColor: [
            "rgba(34, 197, 94, 0.8)",
            "rgba(245, 158, 11, 0.8)",
            "rgba(239, 68, 68, 0.8)"
          ],
          borderColor: [
            "#22c55e",
            "#f59e0b",
            "#ef4444"
          ],
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "70%",
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              usePointStyle: true,
              padding: 15
            }
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            callbacks: {
              label: (context) => {
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const value = context.raw;
                const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                return `${context.label}: ${value} (${percentage}%)`;
              }
            }
          }
        }
      },
      plugins: [{
        id: "centerText",
        beforeDraw: (chart) => {
          const ctx = chart.ctx;
          const chartArea = chart.chartArea;
          const centerX = (chartArea.left + chartArea.right) / 2;
          const centerY = (chartArea.top + chartArea.bottom) / 2;

          // Get current score from chart data
          const currentData = this.getDataForEnv(this.currentEnv);
          const currentScore = currentData.score;

          ctx.save();

          // Draw score value
          ctx.font = "bold 28px sans-serif";
          ctx.fillStyle = this.getScoreColor(currentScore);
          ctx.textAlign = "center";
          ctx.textBaseline = "middle";
          ctx.fillText(`${currentScore}%`, centerX, centerY - 8);

          // Draw label
          ctx.font = "12px sans-serif";
          ctx.fillStyle = "#6b7280";
          ctx.fillText("Stability", centerX, centerY + 16);

          ctx.restore();
        }
      }]
    });
  }

  updateChart(data) {
    const breakdown = data.breakdown;
    this.chart.data.datasets[0].data = [breakdown.stable_7plus, breakdown.stable_3to6, breakdown.unstable];
    this.chart.update();
  }

  disconnect() {
    document.removeEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
    if (this.chart) {
      this.chart.destroy();
    }
  }
}

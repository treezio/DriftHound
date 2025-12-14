import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this.currentEnv = '';
    this.currentStatus = '';
    this.fullData = null;
    this.createChart(this.getDataForEnv(''));

    this.boundHandleFilter = this.handleFilter.bind(this);
    this.boundHandleStatusFilter = this.handleStatusFilter.bind(this);
    document.addEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
    document.addEventListener('dashboard-filter:filterStatus', this.boundHandleStatusFilter);
  }

  handleFilter(event) {
    const env = event.detail.environment || '';
    if (env !== this.currentEnv) {
      this.currentEnv = env;
      this.fullData = this.getDataForEnv(env);
      this.updateChart(this.fullData);
      // Re-apply status filter if active
      if (this.currentStatus) {
        this.applyStatusFilter(this.currentStatus);
      }
    }
  }

  handleStatusFilter(event) {
    const status = event.detail.status || '';
    if (status !== this.currentStatus) {
      this.currentStatus = status;
      this.applyStatusFilter(status);
    }
  }

  applyStatusFilter(status) {
    if (!this.fullData) {
      this.fullData = this.getDataForEnv(this.currentEnv);
    }

    // For doughnut, highlight the selected segment by dimming others
    // Index: 0=ok, 1=drift, 2=error (based on labels order)
    const statusMap = { 'ok': 0, 'drift': 1, 'error': 2 };

    if (!status) {
      // No filter - show all with full opacity
      this.chart.data.datasets[0].backgroundColor = [
        "rgba(34, 197, 94, 0.8)",
        "rgba(245, 158, 11, 0.8)",
        "rgba(239, 68, 68, 0.8)"
      ];
    } else {
      // Dim non-selected segments
      const selectedIndex = statusMap[status];
      this.chart.data.datasets[0].backgroundColor = [
        selectedIndex === 0 ? "rgba(34, 197, 94, 0.9)" : "rgba(34, 197, 94, 0.15)",
        selectedIndex === 1 ? "rgba(245, 158, 11, 0.9)" : "rgba(245, 158, 11, 0.15)",
        selectedIndex === 2 ? "rgba(239, 68, 68, 0.9)" : "rgba(239, 68, 68, 0.15)"
      ];
    }
    this.chart.update();
  }

  getDataForEnv(env) {
    if (!env || env === '') {
      return this.dataValue.all;
    }
    return this.dataValue.by_environment[env] || this.dataValue.all;
  }

  createChart(data) {
    this.chart = new Chart(this.canvasTarget, {
      type: "doughnut",
      data: {
        labels: ["OK", "Drift", "Error"],
        datasets: [{
          data: [data.ok, data.drift, data.error],
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
              label: function(context) {
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = total > 0 ? ((context.raw / total) * 100).toFixed(1) : 0;
                return `${context.label}: ${context.raw} (${percentage}%)`;
              }
            }
          }
        }
      }
    });
  }

  updateChart(data) {
    this.chart.data.datasets[0].data = [data.ok, data.drift, data.error];
    this.chart.update();
  }

  disconnect() {
    document.removeEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
    document.removeEventListener('dashboard-filter:filterStatus', this.boundHandleStatusFilter);
    if (this.chart) {
      this.chart.destroy();
    }
  }
}

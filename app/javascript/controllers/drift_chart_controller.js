import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this.currentEnv = '';
    this.currentStatus = '';
    this.createChart(this.getDataForEnv(''));

    // Listen for filter events from dashboard-filter controller
    this.boundHandleFilter = this.handleFilter.bind(this);
    this.boundHandleStatusFilter = this.handleStatusFilter.bind(this);
    document.addEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
    document.addEventListener('dashboard-filter:filterStatus', this.boundHandleStatusFilter);
  }

  handleFilter(event) {
    const env = event.detail.environment || '';
    if (env !== this.currentEnv) {
      this.currentEnv = env;
      this.updateChart(this.getDataForEnv(env));
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
    // Show/hide datasets based on status filter
    // Index: 0=drift, 1=error, 2=ok
    const statusMap = { 'drift': 0, 'error': 1, 'ok': 2 };

    this.chart.data.datasets.forEach((dataset, index) => {
      if (!status) {
        // No filter - show all
        dataset.hidden = false;
      } else {
        // Show only the selected status
        dataset.hidden = (statusMap[status] !== index);
      }
    });
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
      type: "line",
      data: {
        labels: this.dataValue.dates,
        datasets: [
          {
            label: "Drift",
            data: data.drift,
            borderColor: "#f59e0b",
            backgroundColor: "rgba(245, 158, 11, 0.1)",
            borderWidth: 2,
            tension: 0.3,
            fill: true
          },
          {
            label: "Error",
            data: data.error,
            borderColor: "#ef4444",
            backgroundColor: "rgba(239, 68, 68, 0.1)",
            borderWidth: 2,
            tension: 0.3,
            fill: true
          },
          {
            label: "OK",
            data: data.ok,
            borderColor: "#22c55e",
            backgroundColor: "rgba(34, 197, 94, 0.1)",
            borderWidth: 2,
            tension: 0.3,
            fill: true
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: "index"
        },
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              usePointStyle: true,
              padding: 20
            }
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14 },
            bodyFont: { size: 13 }
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            },
            ticks: {
              maxRotation: 45,
              minRotation: 45
            }
          },
          y: {
            beginAtZero: true,
            ticks: {
              stepSize: 1,
              precision: 0
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)"
            }
          }
        }
      }
    })
  }

  updateChart(data) {
    this.chart.data.datasets[0].data = data.drift;
    this.chart.data.datasets[1].data = data.error;
    this.chart.data.datasets[2].data = data.ok;
    this.chart.update();
  }

  disconnect() {
    document.removeEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
    document.removeEventListener('dashboard-filter:filterStatus', this.boundHandleStatusFilter);
    if (this.chart) {
      this.chart.destroy()
    }
  }
}

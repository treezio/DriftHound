import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this.currentEnv = '';
    this.currentStatus = '';
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
      this.updateChart(this.getDataForEnv(env));
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
    // Show/hide datasets based on status filter
    // Index: 0=ok, 1=drift, 2=error
    const statusMap = { 'ok': 0, 'drift': 1, 'error': 2 };

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
      type: "bar",
      data: {
        labels: this.dataValue.labels,
        datasets: [
          {
            label: "OK %",
            data: data.ok,
            backgroundColor: "rgba(34, 197, 94, 0.8)",
            borderColor: "#22c55e",
            borderWidth: 1
          },
          {
            label: "Drift %",
            data: data.drift,
            backgroundColor: "rgba(245, 158, 11, 0.8)",
            borderColor: "#f59e0b",
            borderWidth: 1
          },
          {
            label: "Error %",
            data: data.error,
            backgroundColor: "rgba(239, 68, 68, 0.8)",
            borderColor: "#ef4444",
            borderWidth: 1
          }
        ]
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
                return `${context.dataset.label}: ${context.raw}%`;
              }
            }
          }
        },
        scales: {
          x: {
            stacked: true,
            grid: {
              display: false
            }
          },
          y: {
            stacked: true,
            beginAtZero: true,
            max: 100,
            ticks: {
              callback: function(value) {
                return value + '%';
              }
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)"
            }
          }
        }
      }
    });
  }

  updateChart(data) {
    this.chart.data.datasets[0].data = data.ok;
    this.chart.data.datasets[1].data = data.drift;
    this.chart.data.datasets[2].data = data.error;
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

import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this.currentEnv = '';
    this.createChart(this.dataValue.all);

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
            label: "Checks",
            data: data,
            backgroundColor: "rgba(59, 130, 246, 0.7)",
            borderColor: "#3b82f6",
            borderWidth: 1,
            borderRadius: 4
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
                return `${context.raw} checks`;
              }
            }
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
    });
  }

  updateChart(data) {
    this.chart.data.datasets[0].data = data;
    this.chart.update();
  }

  disconnect() {
    document.removeEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
    if (this.chart) {
      this.chart.destroy();
    }
  }
}

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
      type: "line",
      data: {
        labels: this.dataValue.labels,
        datasets: [
          {
            label: "Avg Duration (s)",
            data: data,
            borderColor: "#6366f1",
            backgroundColor: "rgba(99, 102, 241, 0.1)",
            borderWidth: 2,
            tension: 0.3,
            fill: true,
            pointBackgroundColor: "#6366f1",
            pointRadius: 3,
            pointHoverRadius: 5
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
              padding: 15
            }
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.raw}s`;
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
              callback: function(value) {
                return value + 's';
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

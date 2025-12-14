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
            label: "Added",
            data: data.adds,
            borderColor: "#22c55e",
            backgroundColor: "rgba(34, 197, 94, 0.3)",
            borderWidth: 2,
            tension: 0.3,
            fill: true,
            pointRadius: 2,
            pointHoverRadius: 4
          },
          {
            label: "Changed",
            data: data.changes,
            borderColor: "#f59e0b",
            backgroundColor: "rgba(245, 158, 11, 0.3)",
            borderWidth: 2,
            tension: 0.3,
            fill: true,
            pointRadius: 2,
            pointHoverRadius: 4
          },
          {
            label: "Destroyed",
            data: data.destroys,
            borderColor: "#ef4444",
            backgroundColor: "rgba(239, 68, 68, 0.3)",
            borderWidth: 2,
            tension: 0.3,
            fill: true,
            pointRadius: 2,
            pointHoverRadius: 4
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
            padding: 12
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
            stacked: true,
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
    this.chart.data.datasets[0].data = data.adds;
    this.chart.data.datasets[1].data = data.changes;
    this.chart.data.datasets[2].data = data.destroys;
    this.chart.update();
  }

  disconnect() {
    document.removeEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
    if (this.chart) {
      this.chart.destroy();
    }
  }
}

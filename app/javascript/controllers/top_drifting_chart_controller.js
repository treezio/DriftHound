import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this.currentEnv = '';
    this.createChart(this.dataValue.all, this.dataValue.labels);

    this.boundHandleFilter = this.handleFilter.bind(this);
    document.addEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
  }

  handleFilter(event) {
    const env = event.detail.environment || '';
    if (env !== this.currentEnv) {
      this.currentEnv = env;
      const data = this.getDataForEnv(env);
      this.updateChart(data.data, data.labels);
    }
  }

  getDataForEnv(env) {
    if (!env || env === '') {
      return { data: this.dataValue.all, labels: this.dataValue.labels };
    }
    const envData = this.dataValue.by_environment[env];
    if (envData) {
      return { data: { rates: envData.rates, counts: envData.counts }, labels: envData.labels };
    }
    return { data: this.dataValue.all, labels: this.dataValue.labels };
  }

  createChart(data, labels) {
    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Drift Rate (%)",
            data: data.rates,
            backgroundColor: "rgba(245, 158, 11, 0.7)",
            borderColor: "#f59e0b",
            borderWidth: 1,
            borderRadius: 4
          }
        ]
      },
      options: {
        indexAxis: 'y',
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
              title: function(tooltipItems) {
                return tooltipItems[0].label;
              },
              label: function(context) {
                return `Drift Rate: ${context.raw}%`;
              }
            }
          }
        },
        scales: {
          x: {
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
          },
          y: {
            grid: {
              display: false
            },
            ticks: {
              callback: function(value, index) {
                const label = this.getLabelForValue(value);
                return label.length > 15 ? label.substring(0, 15) + '...' : label;
              }
            }
          }
        }
      }
    });
  }

  updateChart(data, labels) {
    this.chart.data.labels = labels;
    this.chart.data.datasets[0].data = data.rates;
    this.chart.update();
  }

  disconnect() {
    document.removeEventListener('dashboard-filter:filterChart', this.boundHandleFilter);
    if (this.chart) {
      this.chart.destroy();
    }
  }
}

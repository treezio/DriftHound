import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dashboard-filter"
export default class extends Controller {
  static targets = ["envFilter", "nameFilter", "statusBadge", "clearBtn", "projectRow"];

  connect() {
    this.activeStatus = '';
    this.applyFilters = this.applyFilters.bind(this);
    this.statusBadgeTargets.forEach(badge => {
      badge.addEventListener('click', this.onBadgeClick.bind(this, badge));
    });
    if (this.envFilterTarget) this.envFilterTarget.addEventListener('change', this.applyFilters);
    if (this.nameFilterTarget) this.nameFilterTarget.addEventListener('input', this.applyFilters);
    if (this.clearBtnTarget) this.clearBtnTarget.addEventListener('click', this.clearFilters.bind(this));
  }

  onBadgeClick(badge) {
    this.activeStatus = (this.activeStatus === badge.dataset.statusFilter) ? '' : badge.dataset.statusFilter;
    this.applyFilters();
  }

  applyFilters() {
    const envValue = this.hasEnvFilterTarget ? this.envFilterTarget.value : '';
    const nameValue = this.hasNameFilterTarget ? this.nameFilterTarget.value.trim().toLowerCase() : '';
    const anyActive = !!this.activeStatus || !!envValue || !!nameValue;
    this.projectRowTargets.forEach(row => {
      const matchesEnv = !envValue || row.dataset.environment === envValue;
      const project = row.querySelector('.col-project').textContent.toLowerCase();
      const environment = row.querySelector('.col-environment').textContent.toLowerCase();
      const matchesName = !nameValue || project.includes(nameValue) || environment.includes(nameValue);
      const matchesStatus = !this.activeStatus || row.dataset.status === this.activeStatus;
      row.style.display = (matchesEnv && matchesName && matchesStatus) ? '' : 'none';
    });
    // Highlight active badge
    this.statusBadgeTargets.forEach(badge => {
      if (badge.dataset.statusFilter === this.activeStatus) {
        badge.style.boxShadow = '0 0 0 3px #2563eb55';
        badge.style.transform = 'scale(1.05)';
        badge.style.background = '#e0e7ff';
      } else {
        badge.style.boxShadow = '';
        badge.style.transform = '';
        badge.style.background = '';
      }
    });
    // Highlight env filter
    if (this.hasEnvFilterTarget) {
      if (envValue) {
        this.envFilterTarget.style.background = '#e0e7ff';
        this.envFilterTarget.style.boxShadow = '0 0 0 2px #2563eb55';
      } else {
        this.envFilterTarget.style.background = '';
        this.envFilterTarget.style.boxShadow = '';
      }
    }
    // Show/hide clear button
    if (this.hasClearBtnTarget) this.clearBtnTarget.style.display = anyActive ? '' : 'none';
  }

  clearFilters() {
    if (this.hasEnvFilterTarget) this.envFilterTarget.value = '';
    if (this.hasNameFilterTarget) this.nameFilterTarget.value = '';
    this.activeStatus = '';
    this.applyFilters();
  }
}

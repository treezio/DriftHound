class EnvironmentPolicy < ApplicationPolicy
  def show?
    true
  end

  def destroy?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end

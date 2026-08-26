defmodule Aesir.ZoneServer.Npc.ContentScopeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.ContentScope

  test "activates shared and matching overlay content" do
    assert ContentScope.active?(:shared, :renewal)
    assert ContentScope.active?(:shared, :pre_renewal)
    assert ContentScope.active?(:renewal, :renewal)
    assert ContentScope.active?(:pre_renewal, :pre_renewal)

    refute ContentScope.active?(:renewal, :pre_renewal)
    refute ContentScope.active?(:pre_renewal, :renewal)
  end
end

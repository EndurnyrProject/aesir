defmodule Aesir.Commons.Cluster.SupervisorTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.Cluster

  test "starts the item group pool supervisor" do
    supervisor = Cluster.item_group_pool_supervisor()

    assert is_pid(Process.whereis(supervisor))
  end
end

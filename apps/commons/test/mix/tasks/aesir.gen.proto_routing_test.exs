defmodule Mix.Tasks.Aesir.Gen.ProtoRoutingTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Network.ProtoManifest
  alias Mix.Tasks.Aesir.Gen.ProtoRouting

  describe "the checked-in proto/routing.json" do
    test "is up to date with the aesir.proto annotations" do
      assert ProtoRouting.current?(),
             "proto/routing.json is stale — run `mix aesir.gen.proto_routing`"
    end

    test "is valid JSON describing every annotated message" do
      %{"messages" => messages, "channels" => channels} =
        ProtoRouting.output_path() |> File.read!() |> JSON.decode!()

      assert length(messages) == length(ProtoManifest.entries())

      assert channels == %{
               "control" => 0,
               "gameplay" => 1,
               "world" => 2,
               "bulk" => 3,
               "snapshots" => 4
             }

      navigate_to = Enum.find(messages, &(&1["tag"] == "navigate_to"))

      assert navigate_to == %{
               "field" => 188,
               "tag" => "navigate_to",
               "message" => "NavigateTo",
               "direction" => "s2c",
               "servers" => ["zone"],
               "channel" => "world"
             }
    end

    test "omits the channel for client intents" do
      messages =
        ProtoRouting.output_path() |> File.read!() |> JSON.decode!() |> Map.fetch!("messages")

      for %{"direction" => "c2s"} = message <- messages do
        refute Map.has_key?(message, "channel")
      end
    end
  end

  describe "render/0" do
    test "is idempotent" do
      assert ProtoRouting.render() == ProtoRouting.render()
    end
  end
end

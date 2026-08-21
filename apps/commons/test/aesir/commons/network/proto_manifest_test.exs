defmodule Aesir.Commons.Network.ProtoManifestTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Network.ProtoManifest
  alias Aesir.Commons.Network.ProtoManifest.ParseError
  alias Aesir.Commons.Network.ProtoManifest.Parser
  alias Aesir.Commons.Network.QuinnetCodec

  @source """
  syntax = "proto3";
  package aesir.net;

  message Envelope {
    uint32 seq = 1;

    oneof body {
      // a group comment that is not an annotation
      Hello hello = 16;  // c2s zone,account,char
      HelloAck hello_ack = 17;  // s2c zone,account,char control
      NavigateTo navigate_to = 188;  // s2c zone world
    }
  }
  """

  defp source_without(annotation), do: String.replace(@source, annotation, "")

  describe "Parser.parse_source!/2" do
    test "parses direction, servers and channel of every annotated field" do
      assert [hello, hello_ack, navigate_to] = Parser.parse_source!(@source)

      assert hello == %{
               number: 16,
               tag: :hello,
               module: Aesir.Net.Hello,
               direction: :c2s,
               servers: [:zone, :account, :char],
               channel: nil
             }

      assert hello_ack.direction == :s2c
      assert hello_ack.channel == :control

      assert navigate_to == %{
               number: 188,
               tag: :navigate_to,
               module: Aesir.Net.NavigateTo,
               direction: :s2c,
               servers: [:zone],
               channel: :world
             }
    end

    test "orders entries by proto field number" do
      assert @source |> Parser.parse_source!() |> Enum.map(& &1.number) == [16, 17, 188]
    end

    test "derives the module namespace from the proto package" do
      source = String.replace(@source, "package aesir.net;", "package aesir.other_pkg;")

      assert [%{module: Aesir.OtherPkg.Hello} | _] = Parser.parse_source!(source)
    end

    test "rejects a field with no annotation" do
      source = source_without("  // c2s zone,account,char")

      assert_raise ParseError, ~r/field `hello` has no routing annotation/, fn ->
        Parser.parse_source!(source)
      end
    end

    test "rejects an unknown direction" do
      source = String.replace(@source, "// c2s zone", "// s2s zone")

      assert_raise ParseError, ~r/unknown direction "s2s"/, fn ->
        Parser.parse_source!(source)
      end
    end

    test "rejects an unknown server" do
      source = String.replace(@source, "// s2c zone world", "// s2c battle world")

      assert_raise ParseError, ~r/unknown server "battle"/, fn ->
        Parser.parse_source!(source)
      end
    end

    test "rejects an unknown channel" do
      source = String.replace(@source, "// s2c zone world", "// s2c zone overworld")

      assert_raise ParseError, ~r/unknown channel "overworld"/, fn ->
        Parser.parse_source!(source)
      end
    end

    test "rejects an s2c field with no channel" do
      source = String.replace(@source, "// s2c zone world", "// s2c zone")

      assert_raise ParseError, ~r/must declare exactly one channel/, fn ->
        Parser.parse_source!(source)
      end
    end

    test "rejects a c2s field that declares a channel" do
      source = String.replace(@source, "// c2s zone,account,char", "// c2s zone control")

      assert_raise ParseError, ~r/must not declare a channel/, fn ->
        Parser.parse_source!(source)
      end
    end

    test "rejects a source with no oneof body block" do
      assert_raise ParseError, ~r/no `oneof body` block/, fn ->
        Parser.parse_source!("syntax = \"proto3\";\npackage aesir.net;\n")
      end
    end
  end

  describe "Parser.validate_coverage!/2" do
    test "passes when the annotations cover exactly the envelope oneof" do
      entries = Parser.parse_source!(@source)

      assert Parser.validate_coverage!(entries, [:hello, :hello_ack, :navigate_to]) == entries
    end

    test "fails when an envelope field has no annotation" do
      entries = Parser.parse_source!(@source)

      assert_raise ParseError, ~r/missing \[:brand_new\]/, fn ->
        Parser.validate_coverage!(entries, [:hello, :hello_ack, :navigate_to, :brand_new])
      end
    end

    test "fails when an annotation names a field the envelope no longer has" do
      entries = Parser.parse_source!(@source)

      assert_raise ParseError, ~r/unknown \[:navigate_to\]/, fn ->
        Parser.validate_coverage!(entries, [:hello, :hello_ack])
      end
    end
  end

  describe "the shipped aesir.proto" do
    test "annotates every Envelope oneof field" do
      envelope_tags =
        for {name, field} <- Aesir.Net.Envelope.schema().fields,
            match?(%Protox.OneOf{parent: :body}, field.kind),
            do: name

      assert MapSet.new(ProtoManifest.entries(), & &1.tag) == MapSet.new(envelope_tags)
    end

    test "gives every outbound entry a legal channel and a real oneof tag" do
      channels = QuinnetCodec.channels()

      for server <- ProtoManifest.servers(),
          {module, channel, tag} <- ProtoManifest.outbound(server) do
        assert channel in channels
        assert Map.has_key?(Aesir.Net.Envelope.schema().fields, tag)
        assert Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0)
      end
    end

    test "never lists a message as both inbound and outbound for one server" do
      for server <- ProtoManifest.servers() do
        outbound = MapSet.new(ProtoManifest.outbound(server), &elem(&1, 0))

        assert MapSet.disjoint?(outbound, MapSet.new(ProtoManifest.inbound(server)))
      end
    end

    test "routes the zone messages the servers actually send" do
      assert {Aesir.Net.NavigateTo, :world, :navigate_to} in ProtoManifest.outbound(:zone)
      assert Aesir.Net.MoveRequest in ProtoManifest.inbound(:zone)

      assert {Aesir.Net.LoginResponse, :control, :login_response} in ProtoManifest.outbound(
               :account
             )

      assert {Aesir.Net.CharList, :control, :char_list} in ProtoManifest.outbound(:char)
    end
  end
end

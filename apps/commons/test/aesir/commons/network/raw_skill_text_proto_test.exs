defmodule Aesir.Commons.Network.RawSkillTextProtoTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.ChatMessage
  alias Aesir.Net.Envelope
  alias Aesir.Net.SkillTextInputReply
  alias Aesir.Net.SkillUnitGroupState
  alias Aesir.Net.SkillUnitSpawn

  test "preserves non-UTF-8 bytes in skill input, Scribble state, and Talkie Box output" do
    for {tag, message} <- [
          {:skill_text_input_reply,
           %SkillTextInputReply{request_id: 42, outcome: {:raw_text, <<255, 1, 0, 2>>}}},
          {:skill_unit_spawn, %SkillUnitSpawn{group: %SkillUnitGroupState{message: <<255, 1>>}}},
          {:chat_message, %ChatMessage{gid: 123, raw_message: <<255, 1>>}}
        ] do
      envelope = %Envelope{body: {tag, message}}
      assert {:ok, encoded, _size} = Envelope.encode(envelope)
      assert {:ok, ^envelope} = Envelope.decode(IO.iodata_to_binary(encoded))
    end
  end
end

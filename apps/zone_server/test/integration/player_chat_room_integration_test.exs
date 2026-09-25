defmodule Aesir.ZoneServer.Integration.PlayerChatRoomIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveStop
  alias Aesir.Net.WaitingRoomCreateRequest
  alias Aesir.Net.WaitingRoomCreateResult
  alias Aesir.Net.WaitingRoomInfo
  alias Aesir.Net.WaitingRoomJoinRequest
  alias Aesir.Net.WaitingRoomJoinResult
  alias Aesir.Net.WaitingRoomKickRequest
  alias Aesir.Net.WaitingRoomLeaveRequest
  alias Aesir.Net.WaitingRoomMemberUpdate
  alias Aesir.Net.WaitingRoomRemoved
  alias Aesir.Net.WaitingRoomRoleChanged
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @nv_basic_9 %{1 => 9}

  test "create, password join, gated walk, succession, kick, and destroy" do
    a = player(:a, {150, 150}, learned_skills: @nv_basic_9)
    b = player(:b, {151, 150})
    c = player(:c, {152, 150})
    _observer = player(:o, {153, 150})

    simulate_incoming_message(a.pid, %WaitingRoomCreateRequest{
      title: "Party?",
      password: "pw",
      limit: 5,
      public: false
    })

    assert_receive {:packet, :a, %WaitingRoomCreateResult{result: 0}}
    a_id = a.character.id
    assert_receive {:packet, :o, %WaitingRoomInfo{room_id: room_id, owner_gid: ^a_id}}

    simulate_incoming_message(b.pid, %WaitingRoomJoinRequest{room_id: room_id, password: "no"})
    assert_receive {:packet, :b, %WaitingRoomJoinResult{result: 2}}

    simulate_incoming_message(b.pid, %WaitingRoomJoinRequest{room_id: room_id, password: "pw"})
    b_id = b.character.id

    assert_receive {:packet, :b,
                    %WaitingRoomJoinResult{result: 0, owner_gid: ^a_id, members: members}}

    assert Enum.map(members, & &1.char_id) == [a_id, b_id]

    simulate_incoming_message(b.pid, %MoveRequest{dest_x: 160, dest_y: 160})
    assert_receive {:packet, :b, %MoveStop{gid: ^b_id, x: 151, y: 150}}
    assert {:ok, {_, %{x: 151, y: 150}, _}} = UnitRegistry.get_unit(:player, b_id)

    simulate_incoming_message(a.pid, %WaitingRoomLeaveRequest{})

    assert_receive {:packet, :b,
                    %WaitingRoomRoleChanged{room_id: ^room_id, char_id: ^b_id, owner: true}}

    assert_receive {:packet, :o, %WaitingRoomRemoved{room_id: ^room_id}}
    assert_receive {:packet, :o, %WaitingRoomInfo{room_id: ^room_id, owner_gid: ^b_id}}

    simulate_incoming_message(c.pid, %WaitingRoomJoinRequest{room_id: room_id, password: "pw"})
    assert_receive {:packet, :c, %WaitingRoomJoinResult{result: 0}}

    simulate_incoming_message(b.pid, %WaitingRoomKickRequest{name: c.character.name})
    assert_receive {:packet, :c, %WaitingRoomMemberUpdate{kicked: true}}

    simulate_incoming_message(c.pid, %WaitingRoomJoinRequest{room_id: room_id, password: "pw"})
    assert_receive {:packet, :c, %WaitingRoomJoinResult{result: 6}}

    simulate_incoming_message(b.pid, %WaitingRoomLeaveRequest{})
    assert_receive {:packet, :o, %WaitingRoomRemoved{room_id: ^room_id}}
    assert_eventually(fn -> WaitingRoom.get(room_id) == :error end)
  end

  test "an owner disconnecting hands the room to the next member" do
    a = player(:a, {150, 150}, learned_skills: @nv_basic_9)
    b = player(:b, {151, 150})

    simulate_incoming_message(a.pid, %WaitingRoomCreateRequest{
      title: "Bye",
      password: "",
      limit: 5,
      public: true
    })

    assert_receive {:packet, :a, %WaitingRoomCreateResult{result: 0}}
    assert_receive {:packet, :b, %WaitingRoomInfo{room_id: room_id}}

    simulate_incoming_message(b.pid, %WaitingRoomJoinRequest{room_id: room_id, password: ""})
    assert_receive {:packet, :b, %WaitingRoomJoinResult{result: 0}}

    :ok = GenServer.stop(a.pid, :normal)

    b_id = b.character.id
    assert_receive {:packet, :b, %WaitingRoomRoleChanged{char_id: ^b_id, owner: true}}
    assert {:ok, %WaitingRoom{owner: {:player, ^b_id}}} = WaitingRoom.get(room_id)
  end

  defp player(tag, position, opts \\ []) do
    unique = System.unique_integer([:positive])
    userid = "chat#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    start_player_session(
      Keyword.merge(opts,
        id: unique,
        account_id: account.id,
        name: "#{tag}#{unique}",
        position: position,
        connection_pid: tagged_connection(tag)
      )
    )
  end

  # A fake client connection that forwards every outbound message to the test
  # process tagged with the player it belongs to.
  defp tagged_connection(tag) do
    test_pid = self()
    spawn_link(fn -> forward(test_pid, tag) end)
  end

  defp forward(test_pid, tag) do
    receive do
      {:send, _channel, {_tag, message}} -> send(test_pid, {:packet, tag, message})
      _other -> :ok
    end

    forward(test_pid, tag)
  end
end

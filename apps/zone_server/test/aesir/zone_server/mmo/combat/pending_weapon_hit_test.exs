defmodule Aesir.ZoneServer.Mmo.Combat.PendingWeaponHitTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.PendingWeaponHit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "stores only identity, timing, and symbolic pre-Trifecta continuation" do
    id = make_ref()

    pending =
      PendingWeaponHit.new(
        id,
        {:player, 101},
        {:mob, 202},
        %{unit: {:player, 303}, pid: self()},
        5_000,
        3_000,
        4_200
      )

    assert pending.id == id
    assert pending.attacker == {:player, 101}
    assert pending.target == {:mob, 202}
    assert pending.monk_ref == %{unit: {:player, 303}, pid: self()}
    assert pending.deadline_at == 5_000
    assert pending.swing_at == 3_000
    assert pending.next_attack_at == 4_200
    assert pending.continuation == :pre_trifecta
    refute Map.has_key?(pending, :damage)
    refute Enum.any?(Map.values(pending), &is_function/1)
  end

  test "allows one terminal resolution" do
    pending =
      PendingWeaponHit.new(
        make_ref(),
        {:mob, 101},
        {:player, 202},
        %{unit: {:player, 202}, pid: self()},
        5_000,
        3_000,
        4_200
      )

    assert {:ok, resumed} = PendingWeaponHit.resolve(pending, :resume)
    assert resumed.phase == :resumed
    assert :already_resolved = PendingWeaponHit.resolve(resumed, :suppress)
  end

  test "links a claimed offer and emits one owner cancellation message" do
    id = make_ref()

    pending =
      PendingWeaponHit.new(
        id,
        {:mob, 101},
        {:player, 202},
        %{unit: {:player, 202}, pid: self()},
        5_000,
        3_000,
        4_200
      )

    link_id = make_ref()

    assert {:ok, claimed} = PendingWeaponHit.claim(pending, link_id)
    assert claimed.phase == :claimed
    assert claimed.link_id == link_id
    assert {:ok, cancelled} = PendingWeaponHit.resolve(claimed, :cancel)

    assert PendingWeaponHit.cancellation_message(cancelled) ==
             {:pending_weapon_hit_cancelled, id, {:claim, link_id}}

    assert :already_resolved = PendingWeaponHit.resolve(cancelled, :cancel)
  end

  test "offers stable typed ownership and accepts only a reference claim" do
    pending =
      PendingWeaponHit.new(
        make_ref(),
        {:player, 101},
        {:mob, 202},
        %{unit: {:player, 303}, pid: self()},
        5_000,
        3_000,
        4_200
      )

    assert PendingWeaponHit.offer_message(pending) ==
             {:pending_weapon_hit_offer, pending.id, {:player, 101}, {:mob, 202},
              %{unit: {:player, 303}, pid: self()}, 5_000}

    assert :invalid_link_id = PendingWeaponHit.claim(pending, nil)
    assert :invalid_link_id = PendingWeaponHit.claim(pending, 77)
  end

  test "suppresses only the matching claimed link" do
    pending =
      PendingWeaponHit.new(
        make_ref(),
        {:player, 101},
        {:mob, 202},
        %{unit: {:player, 303}, pid: self()},
        5_000,
        3_000,
        4_200
      )

    link_id = make_ref()
    assert :already_resolved = PendingWeaponHit.resolve(pending, {:suppress, link_id})
    assert {:ok, claimed} = PendingWeaponHit.claim(pending, link_id)
    assert :already_resolved = PendingWeaponHit.resolve(claimed, {:suppress, make_ref()})
    assert {:ok, suppressed} = PendingWeaponHit.resolve(claimed, {:suppress, link_id})
    assert suppressed.phase == :suppressed
  end

  test "storing an offer dispatches once and a claim submits it to the coordinator" do
    pending =
      PendingWeaponHit.new(
        make_ref(),
        {:player, 101},
        {:mob, 202},
        %{unit: {:player, 303}, pid: self()},
        5_000,
        3_000,
        4_200
      )

    game_state = PlayerState.put_pending_weapon_hit(%PlayerState{}, pending)
    pending_id = pending.id

    assert_received {:pending_weapon_hit_offer, ^pending_id, {:player, 101}, {:mob, 202},
                     %{unit: {:player, 303}, pid: owner_pid}, 5_000}

    assert owner_pid == self()

    link_id = make_ref()

    assert {:noreply, %{game_state: %{pending_weapon_hit: claimed}}} =
             PlayerSession.handle_info(
               {:pending_weapon_hit_claimed, pending_id, link_id, self()},
               %{game_state: game_state}
             )

    assert claimed.phase == :claimed

    assert_received {:pending_weapon_hit_pair_submission, ^link_id,
                     %PendingWeaponHit{
                       id: pending_id,
                       attacker: {:player, 101},
                       target: {:mob, 202}
                     }}

    assert pending_id == pending.id
  end
end

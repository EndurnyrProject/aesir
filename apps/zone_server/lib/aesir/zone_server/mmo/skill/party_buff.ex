defmodule Aesir.ZoneServer.Mmo.Skill.PartyBuff do
  @moduledoc """
  Shares a self-cast status with eligible nearby party members.

  Status parameters, including duration, are supplied by the caster's skill and
  reused unchanged for every recipient.
  """

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @hilt_binding_id 105

  @doc """
  Returns the caster-derived party-buff duration.

  Hilt Binding extends the duration by 10%. Fractional milliseconds are truncated.
  """
  @spec duration_for_caster(PlayerState.t(), non_neg_integer()) :: non_neg_integer()
  def duration_for_caster(caster, duration) do
    if PlayerStats.skill_level(caster.stats, @hilt_binding_id) > 0 do
      div(duration * 110, 100)
    else
      duration
    end
  end

  @doc """
  Applies `status` to the caster and eligible online party members within `range`.

  `params` may carry `own:`, extra parameters for the caster's own application
  only (the reference self-cast flag of Adrenaline Rush, Weapon Perfection and
  Over Thrust: `own: [val2: 1]`).

  The reference starts the status on the caster and on each member
  independently and never fails the cast for a refused recipient, so a refusal
  is skipped rather than propagated.
  """
  @spec apply(PlayerState.t(), atom(), keyword(), non_neg_integer(), (PlayerState.t() ->
                                                                        boolean())) :: :ok
  def apply(caster, status, params, range, eligible? \\ fn _candidate -> true end) do
    {own, params} = Keyword.pop(params, :own, [])
    own_params = Keyword.merge(params, own)

    StatusInterpreter.apply_status(:player, caster.character_id, status, own_params)

    caster
    |> party_members()
    |> Enum.each(&apply_to_member(&1, caster, status, params, range, eligible?))

    :ok
  end

  @doc """
  Executes a cash-party skill without invoking an ordinary support skill.

  A player in a party uses cash fanout; solo players and other casters apply
  directly to the resolved recipient. Player-owned events are returned for
  selected reconciliation, even when an application makes no change.
  """
  @spec cast_cash(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
          | {:local_effects, PlayerState.t(), [Active.effect()]}
          | {:error, atom()}
  def cast_cash(caster, target, level, definition) do
    adapter = Caster.for(caster)

    params = [
      val1: level,
      duration: Enum.at(definition.duration, level - 1, List.last(definition.duration) || 0),
      caster_id: adapter.id(caster),
      source_type: adapter.unit_type(caster),
      skill_id: definition.id
    ]

    cash_cast(caster, target, definition, params)
  end

  defp cash_cast(%PlayerState{party_id: 0} = caster, _target, %{id: 693}, _params) do
    {:local_effects, caster, [{:player, {:status_events, []}}, {:player, {:skill_failed, 693}}]}
  end

  defp cash_cast(%PlayerState{party_id: party_id} = caster, _target, definition, params)
       when party_id != 0 do
    events = apply_cash(caster, definition.status, params, definition.splash_radius)
    {:local_effects, caster, [{:player, {:status_events, events}}]}
  end

  defp cash_cast(caster, target, definition, params) do
    with {:ok, type, id, recipient} <- cash_target(caster, target) do
      own? = is_struct(caster, PlayerState) and type == :player and id == caster.character_id
      params = Keyword.put(params, :owner_refresh, if(own?, do: :defer, else: :notify))
      result = StatusInterpreter.apply_status_with_events(type, id, definition.status, params)
      cash_visual(recipient, params, result)
      events = if own?, do: cash_events(result), else: []

      case caster do
        %PlayerState{} ->
          {:local_effects, caster, [{:player, {:status_events, events}}]}

        _non_player ->
          {:ok, caster}
      end
    end
  end

  defp cash_target(caster, :self) do
    adapter = Caster.for(caster)
    {:ok, adapter.unit_type(caster), adapter.id(caster), caster}
  end

  defp cash_target(_caster, {:unit, {type, id}}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, recipient, _pid}} -> {:ok, type, id, recipient}
      {:error, _reason} -> {:error, :target_not_found}
    end
  end

  defp cash_target(caster, {:unit, id}) when is_integer(id) do
    with {:ok, type} <- UnitRegistry.unit_type_for(id) do
      cash_target(caster, {:unit, {type, id}})
    end
  end

  defp cash_events({:ok, events}), do: events
  defp cash_events({:error, _reason, events}), do: events

  defp cash_visual(_recipient, _params, {:error, :target_dead, _events}), do: :ok

  defp cash_visual(recipient, params, result) do
    case Keyword.get(params, :skill_id) do
      nil ->
        :ok

      skill_id ->
        adapter = Caster.for(recipient)
        id = adapter.id(recipient)
        {map, x, y} = adapter.position(recipient)

        Broadcast.to_in_range(map, x, y, Config.view_range(), %SkillEffect{
          skill_id: skill_id,
          level: Keyword.fetch!(params, :val1),
          src_id: if(skill_id == 693, do: Keyword.fetch!(params, :caster_id), else: id),
          target_id: id,
          result: if(match?({:ok, _}, result), do: 1, else: 0)
        })
    end
  end

  @doc """
  Applies a cash-party status to online, world-placed members, including the caster.

  Missing parties have no recipients. Every member passes the same square-range
  and targeting gates. Only the caster's committed events are returned for inline
  reconciliation; other recipients receive their normal owner notifications.
  The original skill invocation remains active throughout delivery.
  """
  @spec apply_cash(PlayerState.t(), atom(), keyword(), non_neg_integer()) ::
          [StatusInterpreter.status_event()]
  def apply_cash(caster, status, params, range) do
    params = Keyword.merge(params, caster_id: caster.character_id, source_type: :player)

    with true <- Unit.living?(caster),
         {:ok, party} <- PartyManager.get(caster.party_id) do
      party
      |> PartyState.online_members()
      |> Enum.flat_map(&apply_cash_member(&1.char_id, caster, status, params, range))
    else
      _no_recipients -> []
    end
  end

  defp apply_cash_member(id, caster, status, params, range) do
    with {:ok, {_module, %PlayerState{pending_map_load: nil} = member, _pid}} <-
           UnitRegistry.get_unit(:player, id),
         true <- member.map_name == caster.map_name,
         true <-
           range == 0 or Geometry.in_tile_range?(caster.x, caster.y, member.x, member.y, range),
         true <- Targeting.cash_party_recipient?(caster, member) do
      own? = id == caster.character_id
      params = Keyword.put(params, :owner_refresh, if(own?, do: :defer, else: :notify))

      result = StatusInterpreter.apply_status_with_events(:player, id, status, params)
      cash_visual(member, params, result)
      if own?, do: cash_events(result), else: []
    else
      _ineligible -> []
    end
  end

  defp apply_to_member(member, caster, status, params, range, eligible?) do
    if nearby_and_eligible?(member.char_id, caster, range, eligible?) do
      StatusInterpreter.apply_status(:player, member.char_id, status, params)
    end
  end

  defp party_members(%{party_id: 0}), do: []

  defp party_members(%{party_id: party_id, character_id: caster_id}) do
    case PartyManager.get(party_id) do
      {:ok, party} ->
        party
        |> PartyState.online_members()
        |> Enum.reject(&(&1.char_id == caster_id))

      {:error, _reason} ->
        []
    end
  end

  defp nearby_and_eligible?(char_id, caster, range, eligible?) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{} = candidate, _pid}} ->
        candidate.map_name == caster.map_name and
          Unit.living?(candidate) and
          not Invincibility.active?(candidate) and
          Geometry.in_tile_range?(caster.x, caster.y, candidate.x, candidate.y, range) and
          eligible?.(candidate)

      {:error, :not_found} ->
        false
    end
  end
end

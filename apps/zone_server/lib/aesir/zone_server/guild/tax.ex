defmodule Aesir.ZoneServer.Guild.Tax do
  @moduledoc """
  Per-member guild EXP taxation.

  A member's tax rate is the `tax` percentage of their guild position, cached
  on `PlayerState.guild_tax` by the social handler (refreshed on guild attach
  and on every guild broadcast). `apply/2` diverts that share of earned base
  EXP; `contribute_async/2` forwards it to the guild entry without blocking
  the member's session. Job EXP is never taxed.
  """

  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc """
  Splits earned base EXP into `{kept, taxed}` using the cached tax rate.

  Guildless players and untaxed positions pass through unchanged; the taxed
  share is `floor(base_amount * tax / 100)`.
  """
  @spec apply(PlayerState.t(), non_neg_integer()) :: {non_neg_integer(), non_neg_integer()}
  def apply(%PlayerState{guild_id: guild_id, guild_tax: tax}, base_amount)
      when guild_id in [nil, 0] or tax in [nil, 0] do
    {base_amount, 0}
  end

  def apply(%PlayerState{guild_tax: tax}, base_amount) do
    taxed = div(base_amount * tax, 100)
    {base_amount - taxed, taxed}
  end

  @doc """
  Fire-and-forget credit of a taxed amount to the guild entry.

  Runs `Manager.contribute_exp/2` on a throwaway task so the member's session
  never blocks on the guild entry or its DB write; a zero amount is a no-op.
  """
  @spec contribute_async(non_neg_integer(), non_neg_integer()) :: :ok
  def contribute_async(_guild_id, 0), do: :ok

  def contribute_async(guild_id, taxed) do
    {:ok, _pid} = Task.start(fn -> Manager.contribute_exp(guild_id, taxed) end)
    :ok
  end
end

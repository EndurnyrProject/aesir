defmodule Aesir.Commons.Network.Packetver do
  @moduledoc """
  Single source of truth for the client packet version this build targets.

  Ragnarok Online's wire protocol changes shape between client releases: the same
  logical packet can change its numeric ID, its size, or the encoding of its
  fields from one release to the next. rAthena handles this with a compile-time
  `#define PACKETVER 20211103` that the whole build is fixed to.

  Aesir follows the same **per-build global** model: a single running server
  speaks exactly one packetver, chosen at compile time. To target a different
  client you change the configured value and recompile. There is no per-connection
  negotiation today.

  Versions are represented as 8-digit `"YYYYMMDD"` **strings** (a date code, not a
  quantity — you only ever order them, never do arithmetic). Because every RO
  packetver is exactly 8 digits, lexicographic string comparison matches
  chronological order, so `>=` works as expected.

  ## Configuration

      # config/config.exs
      config :commons, packetver: "20211103"

  The value is read with `Application.compile_env/3`, so changing it forces a
  recompile of every module that branches on it (which is the point — the byte
  layouts are baked in at compile time).

  The default, `"20211103"`, is the Renewal (`PACKETVER_RE_NUM`) cutoff that the
  current packet layouts assume.

  ## Convention for version-sensitive packets

  When a packet's ID/size/layout diverges across versions, keep it in **one
  module** and branch with guard clauses on the configured version, picking the
  greatest layout the build's version qualifies for:

      alias Aesir.Commons.Network.Packetver

      @impl true
      def packet_id, do: do_packet_id(Packetver.current())

      defp do_packet_id(pv) when pv >= "20211103", do: 0x0B72
      defp do_packet_id(_pv), do: 0x0AC5

  A module that only ever had one layout needs none of this — it just hardcodes
  the current values as it does today. Only declare a clause at the packetver
  where the layout actually changed.

  ## Future extensions (deliberately not built yet)

  - **Client flavor.** rAthena distinguishes RE / Main / Zero lines, which share
    the date numbering but cut over at different dates (e.g. a layout is RE
    `>= "20211103"` but Main `>= "20220330"`). We target Renewal only, so the
    bare date is unambiguous for now.
  - **Per-connection version.** Carrying the version in session state instead of
    a build constant would let one server serve mixed clients. The session layer
    already exists to hold it; the registry/dispatch would then need a version
    argument. Not needed while we ship a single client target.
  """

  @typedoc "A client packet version as an 8-digit `YYYYMMDD` date code, e.g. `\"20211103\"`."
  @type packetver :: String.t()

  @default_packetver "20211103"

  @packetver Application.compile_env(:commons, :packetver, @default_packetver)

  @doc """
  Returns the packetver this build was compiled against.
  """
  @spec current() :: packetver()
  def current, do: @packetver

  @doc """
  Returns `true` when the configured packetver is at least `version`.

  Use this to gate a layout to the version it was introduced in. Comparison is
  lexicographic, which matches chronological order for 8-digit date codes.
  """
  @spec at_least?(packetver()) :: boolean()
  def at_least?(version) when is_binary(version), do: current() >= version
end
